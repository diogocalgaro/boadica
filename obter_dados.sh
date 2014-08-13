#!/bin/bash

#config basica
source $(dirname $0)/config.inc

#funcoes
source ${base}/funcoes.inc

#parametros
categ_id="${1}" #id da categoria (obrigatorio)
test -z "$categ_id" && fatal "Nenhum id foi informada. Não é possível continuar."

if [ -n "${2}" ] #url da primeira pagina da categoria (opcional, pra agilizar o processo)
then
	url="${2}"
else
	#obtendo url da categoria
	url=$(sqlite3 ${db} "select url from categorias where id = '$categ_id';")
	test -z "$url" && fatal "Nenhuma URL foi encontrada. Não é possível continuar."
	url=${site}${url}
fi

#variaveis
sql_insert="insert or replace"
arq="${workdir}/pag1"
arq2="$(mktemp)" #trecho da tabela da pagina
arq3="$(mktemp)" #cache da tabela de locais
sql="$(mktemp)"  #arquivo com os inserts pro sqlite
p=""
quando="$(date +'%Y-%m-%d')"
urlprox=""
urlult=""
pag=0
ult_pag=""

#limpando a area temporaria de downloads
echo "Iniciando coletor de dados..."
echo -n "Limpando diretório de trabalho... "
rm -f ${workdir}/*
test $? -eq 0 && echo "[OK]" || echo "[Falhou]"

#baixando a primeira pagina e obtendo o numero da ultima
echo -n "Baixando a primeira página da categoria... "
dw="$(basename $(which $dw_opcoes 2>/dev/null | head -n1))"
case "$dw" in
	"curl") curl --compressed -s -o "$arq" "$url" ;;
	"aria2c")
		dn="$(dirname $arq)"
		bn="$(basename $arq)"
		aria2c --auto-file-renaming=false --allow-overwrite=true -q -o "$bn" -d "$dn" "$url" ;;
	"wget") wget --no-use-server-timestamps -q -O "$arq" "$url" ;;
esac
test $? -eq 0 && echo "[OK]" || echo "[Falhou]"
if [ ! -s "$arq" ]
then
	fatal "Não foi possível baixar a primeira página."
fi

#obtendo o numero da ultima pagina
urlult="$(grep -m1 'ltima</a>' $arq)"
if [ $? -eq 0 ]
then
	urlult=${urlult#*\'}
	urlult=${urlult%%\'*}
	ult_pag=${urlult#*curpage=}
	ult_pag=${ult_pag%%&*}
else
	ultpag=1
fi
if [ ${ult_pag:-0} -gt ${max_pags} ]
then
	ult_pag=$max_pags
fi
echo "INFO: Última página da categoria = $ult_pag"

#baixando as demais paginas
if [ ${ult_pag:-0} -gt 1 ]
then
	echo -n "Baixando as demais páginas... "
	todas=""
	case "$dw" in
		"curl")
			arq="${workdir}/pag#1"
			todas="${url}&curpage=[2-${ult_pag}]"
			curl --compressed -s -o "$arq" "$todas"
			test $? -eq 0 && echo "[OK]" || echo "[Falhou]"
			;;
		"aria2c")
			arq_urls="$(mktemp)"
			for i in $(seq 2 $ult_pag)
			do
				echo -e "${url}&curpage=${i}\n out=pag${i}" >> "$arq_urls"
			done
			aria2c -j 5 -q -i "$arq_urls" -d ${workdir}
			test $? -eq 0 && echo "[OK]" || echo "[Falhou]"
			rm "$arq_urls"
			;;
		"wget")
			for i in $(seq 2 $ult_pag)
			do
				todas="${todas}${url}&curpage=${i} "
			done
			wget --no-use-server-timestamps -q -P "${workdir}/" -i - <<< echo $todas
			test $? -eq 0 && echo "[OK]" || echo "[Falhou]"
			;;
	esac
fi

baixados="$(ls ${workdir} | wc -l)"
if [ ${baixados:-0} -lt ${ult_pag:-1} ]
then
	echo
	echo "AVISO: o número de páginas baixadas é menor que o total de páginas disponíveis no site."
	read -p "Continuar? [Enter=Sim / Ctrl-C=Não]" r
fi

#obtendo cache da lista de locais pra agilizar o processo
echo -n "Obtendo cache dos locais (bairros)... "
sqlite3 -list -separator ";" "$db" "select id, nome from locais order by id" > "$arq3"
test $? -eq 0 && echo "[OK]" || echo "[Falhou]"
ult_idlocal=$(tail -n1 "$arq3")
ult_idlocal=${ult_idlocal%%;*}
prox_idlocal=$(( ult_idlocal + 1 )) #proximo valor de ID pra tabela LOCAIS

#preparando arquivo sql
echo
echo "Iniciando processamento das páginas baixadas..."
echo
echo "begin;" > "$sql"

#processando as paginas HTML baixadas
IFS=$'\n'
for f in $(find ${workdir} -maxdepth 1 -type f)
do
	arq="$f"
	echo -n "Processando arquivo: $arq "

	#verificando se a categoria nao esta vazia
	grep -m1 'Nenhuma oferta com estes argumentos' $arq >/dev/null 2>&1
	if [ $? -eq 0 ]
	then
		echo ' [VAZIO]'
		continue
	fi

	#salvando a parte interessante do arquivo
	inicio="$(grep -nw -m1 '<tbody>' $arq)"
	inicio="${inicio%%:*}"
	final="$(grep -nw -m1 '</tbody>' $arq)"
	final="${final%%:*}"
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

	#processamento a tabela da pagina
	while read i
	do
		i2="${i#"${i%%[![:space:]]*}"}" #trim

		if [ "${i2:0:3}" == "<tr" ]
		then
			col=0
			noreg=1
			cont=""
		elif [ "${i2:0:5}" == "</tr>" ]
		then
			noreg=0
			cont2=${cont%$'\r\n'*}
			cont2=${cont2#*>}
			cont2=${cont2%</td*}
			localizacao="${cont2/'<br/>'/ - }"
			idlocal=$(grep -hm1 "${localizacao}" "$arq3") #procurando o ID do LOCAL no arquivo de cache
			idlocal=${idlocal%%;*}

			if [ -z "$idlocal" ] #novo local
			then
				echo "${prox_idlocal:-1};${localizacao}" >> "$arq3"
				idlocal="${prox_idlocal:-1}"
				echo "$sql_insert into locais (id, nome, consultar) values ($idlocal, '$localizacao', 'S');" >> "$sql"
				(( prox_idlocal++ ))
			fi

			echo "$sql_insert into produtos (id, categoria, fabricante, nome, favorito) values ($idprod, '${categ_id:-0}', '$fabricante', '$produto', 'N');" >> "$sql"
			echo "$sql_insert into lojas (id, nome, local) values ('$idloja', '$loja', '$idlocal');" >> "$sql"
			echo "$sql_insert into precos (produto, loja, data, valor_num, valor_str) values ($idprod, '$idloja', '$quando', '$preco', '$precof');" >> "$sql"

		elif [ "${i2:0:4}" == "<td>" ]
		then
			if [ $col -gt 0 ]
			then
				cont2=${cont//$'\r'}
				cont2=${cont2//$'\n'}
				cont2=${cont2#*>}
				cont2=${cont2%<*}
			fi

			case $col in
				2) 
				   cont2=${cont2#*>}
				   fabricante=${cont2%<*}
				   fabricante="${fabricante#"${fabricante%%[![:space:]]*}"}" ;;

				3) 
				   produto=${cont2%%<*}
				   produto=${produto/' - BOX'}
				   produto=${produto#"${produto%%[![:space:]]*}"}
				   idprod=${cont2##*/produtos/p}
				   idprod=${idprod%%\" *} ;;

				5) preco=${cont2/'R$'}
				   preco=${preco//' '}
				   preco=${preco/'</td'}
				   preco=${preco/./}
				   precof="$(printf '%.2f' $preco)" #1,11 1,10 1,00 (valor_str)
				   preco=${preco/,/.} ;;            #1.11 1.1  1    (valor_num)

				6) 
				   loja=${cont2#*>}
				   loja=${loja%%<*}
				   idloja=${cont2#*codigo=}
				   idloja=${idloja%%\'*} ;;
			esac

			((col++))
			cont="${i2}"
		elif [ "$noreg" == "1" ]
		then
			cont="${cont} ${i2}"
		fi
	done < "$arq2"

	echo " [OK]"
done

#preparando arquivo sql
echo "commit;" >> "$sql"
echo

#gravando no banco de dados
echo -n "Salvando no banco de dados... "
fav=$(sqlite3 -csv "$db" "select id from produtos where favorito='S' order by 1;" | tr '\n' ',') #guardando os favoritos pra recupera-los depois da carga dos novos dados
fav="${fav}000"
sqlite3 -batch "$db" < "$sql"
if [ $? -eq 0 ]
then
	sqlite3 "$db" "update produtos set favorito='S' where id in ($fav);"
	if [ $? -eq 0 ]
	then
		echo "[OK]"
	else
		echo
		echo "AVISO: Falha ao recuperar favoritos..."
	fi
else
	echo
	echo "Arquivos temporários utilizados:"
	echo "Último corte de página HTML: $arq2"
	echo "Cache dos locais: $arq3"
	echo "Script SQL: $sql"
	fatal "Falha ao gravar na base de dados..."
fi

#finalizando
rm "$arq"
rm "$arq2"
rm "$arq3"
rm "$sql"
rm -f ${workdir}/* >/dev/null 2>&1
echo
echo "Concluído."
