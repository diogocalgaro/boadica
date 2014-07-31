#!/bin/bash

#config basica
source $(dirname $0)/config.inc

#variaveis
sql_insert="insert or replace"
max_pags=99
arq="$(mktemp)"  #pagina html completa, baixada no site
arq2="$(mktemp)" #trecho da tabela da pagina
arq3="$(mktemp)" #cache da tabela de locais
sql="$(mktemp)"  #arquivo com os inserts pro sqlite
p=""
quando="$(date +'%Y-%m-%d')"
url="$url_dados"
urlprox=""
urlult=""
pag=0
ult_pag=""

#obtendo cache da lista de locais pra agilizar o processo
sqlite3 -list -separator ";" "$db" "select id, nome from locais" > "$arq3"
ult_idlocal=$(tail -n1 "$arq3" | cut -d';' -f1)
prox_idlocal=$(( ult_idlocal + 1 )) #proximo valor de ID pra tabela LOCAIS

#fazendo backup da base de dados
rm ${db}.gz 2>/dev/null
gzip -k ${db}

#preparando arquivo sql
echo "begin;" >> "$sql"

#principal
while [ -n "$url" ]
do
	#pagina
	(( pag++ ))
	if [ $pag -gt $max_pags ]
	then
		break
	fi

	#baixando a pagina
        which curl > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
                curl --compressed -s -o "$arq" "$url"
        else
                which aria2c > /dev/null 2>&1
                if [ $? -eq 0 ]
                then
                        aria2c -q -o "$arq" "$url"
                else
                        which wget > /dev/null 2>&1
                        if [ $? -eq 0 ]
                        then
                                wget -q -O "$arq" --no-use-server-timestamps "$url"
                        else
                                echo "Nenhum programa de download disponível..."
                                exit 1
                        fi
                fi
        fi

	if [ ! -s "$arq" ]
	then
		echo "Não conseguiu baixar o arquivo..."
		exit 1
	fi

	#salvando a parte interessante do arquivo
	inicio="$(grep -nw -m1 '<tbody>' $arq | cut -d':' -f1)"
	final="$(grep -nw -m1 '</tbody>' $arq | cut -d':' -f1)"
	dif="$((final - inicio))"
	head -n${final} "$arq" | tail -n${dif} | iconv -f "ISO-8859-1" -t "UTF-8" > "$arq2"

	#controle
	col=0 #int
	noreg=0 #bool
	cont="" #char

	#dados
	idprod=""
	fabricante=""
	produto=""
	preco=""
	precof=""
	idloja=""
	loja=""
	localizacao=""

	#processamento
	while read i
	do
		i2="${i#"${i%%[![:space:]]*}"}" #trim leading spaces

		if [ "${i2:0:3}" == "<tr" ]
		then
			col=0
			noreg=1
			cont=""
		elif [ "${i2:0:5}" == "</tr>" ]
		then
			noreg=0
			cont2=$(echo $cont | tr -d '\r\n' | cut -d'>' -f2-)
			cont2=${cont2/'</td'}
			localizacao="${cont2/'<br/>'/ - }" #nao pode colocar aspas simples no segundo parametro - fedora
			localizacao="${localizacao/'>'}" #o delimitador acabou sendo incluido no cut acima - ubuntu
			idlocal=$(grep -hm1 "${localizacao}" "$arq3" | cut -d';' -f1) #procurando o ID do LOCAL no arquivo de cache

			if [ -z "$idlocal" ] #novo local
			then
				echo "${prox_idlocal:-1};${localizacao}" >> "$arq3"
				idlocal="${prox_idlocal:-1}"
				echo "$sql_insert into locais (id, nome, consultar) values ($idlocal, '$localizacao', 'S');" >> "$sql"
				(( prox_idlocal++ ))
			fi

			echo "$sql_insert into produtos (id, fabricante, nome) values ($idprod, '$fabricante', '$produto');" >> "$sql"
			echo "$sql_insert into lojas (id, nome, local) values ('$idloja', '$loja', '$idlocal');" >> "$sql"
			echo "$sql_insert into precos (produto, loja, data, valor_num, valor_str) values ($idprod, '$idloja', '$quando', '$preco', '$precof');" >> "$sql"

		elif [ "${i2:0:4}" == "<td>" ]
		then
			if [ $col -gt 0 ]
			then
				cont2=$(echo $cont | tr -d '\r\n' | cut -d'>' -f2-)
				cont2=${cont2/'</td>'}
			fi

			case $col in
				2) fabricante="$(echo $cont2 | cut -d'>' -f2- | cut -d'<' -f1)" ;;

				3) produto="$(echo $cont2 | cut -d '<' -f1)"
				   produto="${produto/' - BOX'}"

				   #gambiarras pra pegar o codigo do produto
				   p=$(echo $cont2 | grep -b -o -m1 '/produtos/p' | head -n1 | cut -d':' -f1)
				   (( p += 6 ))
				   idprod=${cont2:$p:20}
				   idprod=$(echo $idprod | cut -d'p' -f2)
				   idprod=$(echo $idprod | cut -d'"' -f1) ;;

				5) preco=${cont2/'R$'}
				   preco=${preco//' '}
				   preco=${preco/'</td'}
				   preco=${preco/./}
				   precof="$(printf '%.2f' $preco)" #1,11 1,10 1,00 (valor_str)
				   preco=${preco/,/.} ;;            #1.11 1.1  1    (valor_num)

				6) loja="$(echo $cont2 | cut -d'>' -f2 | cut -d'<' -f1)"
				   p=$(echo $cont2 | grep -b -o -m1 'codigo=' | head -n1 | cut -d':' -f1)
				   (( p += 8 ))
				   idloja="${cont2:$p:32}" ;;
			esac

			((col++))
			cont="${i2}"
		elif [ "$noreg" == "1" ]
		then
			cont="${cont} ${i2}"
		fi

	done < "$arq2"

	#verificando e obtendo a proxima pagina
	urlprox="$(grep -m1 'xima</a>' $arq | cut -d"'" -f2)"

	if [ -n "$urlprox" ]
	then
		url="${site}${urlprox}"
	else
		url=""
	fi

	#verificando e obtendo a ultima  pagina
	if [ -z "$ult_pag" ]
	then
		urlult="$(grep -m1 'ltima</a>' $arq | cut -d"'" -f2)"
		ult_pag="$(echo "$urlult" | grep -om1 'curpage=\([0-9]\|[0-9][0-9]\|[0-9][0-9][0-9]\)' | cut -d'=' -f2)"
	fi

	#barra de progresso
	perc=$(echo "scale=2;${pag}/${ult_pag}*100" | bc)
	perc=$(echo "${perc}/1" | bc)
	echo $perc

done | whiptail --title "Carga de Dados" --gauge "Carregando dados de hoje" 7 50 0

#preparando arquivo sql
echo "commit;" >> "$sql"

#gravando no banco de dados
echo "Salvando no banco de dados..."
fav=$(sqlite3 -csv "$db" "select id from produtos where favorito='S' order by 1;" | tr '\n' ',') #guardando os favoritos pra recupera-los depois da carga dos novos dados
fav="${fav}000"
sqlite3 -batch "$db" < "$sql"
if [ $? -eq 0 ]
then
	sqlite3 "$db" "update produtos set favorito='S' where id in ($fav);"
	if [ $? -eq 0 ]
	then
		whiptail --title "Carga de Dados" --msgbox "Dados carregados com sucesso." 7 35
	else
		echo "Falha ao recuperar favoritos..."
		exit 1
	fi
else
	echo "Falha ao gravar dados na base..."
	exit 1
fi

#finalizando
rm "$arq"
rm "$arq2"
rm "$arq3"
rm "$sql"
