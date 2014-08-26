#!/bin/bash

#dependencias
source $(dirname $0)/_config.inc
source ${base}/_funcoes.inc

#variaveis
arq="$(mktemp)"
arq2="$(mktemp)"
arq3="$(mktemp)"
arq4="$(mktemp)"
arq5="$(mktemp)"
dw="$(basename $(which $dw_opcoes 2>/dev/null | head -n1))"

#baixando a pagina
dialog --title "Setup" --infobox "Obtendo página inicial da pesquisa de preços. Aguarde." 4 62
case "$dw" in
	"curl") curl --compressed -s -o "$arq" "$url_base" ;;
	"aria2c")
	        dn="$(dirname $arq)"
	        bn="$(basename $arq)"
	        aria2c --auto-file-renaming=false --allow-overwrite=true -q -o "$bn" -d "$dn" "$url_base" ;;
	"wget") wget -q -O "$arq" --no-use-server-timestamps "$url_base" ;;
esac
if [ ! -s "$arq" ]
then
	fatal "Não conseguiu baixar o arquivo: ${url_base} em ${arq}"
fi

#parseando a pagina
linha1=$(grep -nw -m1 '<div class="menu-dropdown-topo">' "$arq")
linha1=${linha1%%:*}
linha2=$(grep -nw -m1 '<li><a href="/iniciodrivers.asp">Drivers</a></li>' "$arq")
linha2=${linha2%%:*}
dif=$((linha2 - linha1))
head -n${linha2} "$arq" | tail -n${dif} | grep '/pesquisa/' | iconv -f "ISO-8859-1" -t "UTF-8" | sed 's/^[ \t]*//' > "$arq2"
num_linhas=$(cat $arq2 | wc -l)

#montando as opcoes pro menu
dialog --title "Setup" --infobox "Montando o menu de opções..." 4 40
while read i
do
	linha="${i%$'\r\n'*}"
	linha="${linha#"${linha%%[![:space:]]*}"}"
	linha="${linha/<li><a href=}"
	tipo=""

	if [ "${linha: -6:5}" == '</li>'  ] #tem q ter espaco entre o 'dois pontos' e o  'menos 6', fica sobrando um caracter entre o '>' e o 'fim de linha'
	then
	        tipo="s"
	else
	        tipo="c"
	fi

	linha=${linha%</a>*}
	linha=${linha%\"} #sem aspas em volta
	linha=${linha/\" ou/ ou}
	linha=${linha}'"'

	if [ "$tipo" == "c" ]
	then
	        linha=${linha/>/\|\"┣━━━━━━━━━━}
	        cod='"C"'
	else
	        linha=${linha/>/\|\"┣}
	        cod=${linha%\|*}
	fi

	desc=${linha#*\|}
	echo "$cod|$desc|off " >> "$arq3"

done < "$arq2"

#perguntando a categoria
urls=0
out=3
while true # [ -z "$urls" ]
do
	if [ $out -eq 3 ]
	then
		if [ -z "${urls}" ]
		then
			sed ':a;N;$!ba;s/\n/ /g;s/|/ /g;s/ off/ on/g' ${arq3} > ${arq5}
		else
			sed ':a;N;$!ba;s/\n/ /g;s/|/ /g' ${arq3} > ${arq5}
		fi
	elif [ $out -eq 0 ]
	then
		break
	fi
	eval "urls=\$(dialog --single-quoted --stdout --no-tags --no-cancel --extra-button --extra-label 'Todas/Nenhuma' --title 'Setup' --checklist 'Selecione a(s) categoria(s) que deseja utilizar' 40 100 28 $(cat ${arq5}))"
	out=$?
done

#inserindo as categorias no banco de dados
inseridas=0
for i in $urls
do
	if [ "${i}" == "C" ]
	then
	        continue
	fi

	i=${i//\'}
	categ="$(grep -m1 "$i" $arq3)"
	categ=${categ#*|}
	categ=${categ%|*}
	categ=${categ//\"}
	categ=${categ:1}
	echo -n $categ

	#verificando se a categoria existe antes de inserir
	existe=$(sqlite3 dados.sqlite3 "select count(*) from categorias where url = '${i}';")
	if [ ${existe:-0} -eq 0 ]
	then
	        sqlite3 "${db}" "insert into categorias (nome, url, consultar) values('${categ}', '${i}', 'S');"
	        if [ $? -eq 0 ]
	        then
	                (( inseridas++ ))
	                echo "$inseridas" > "$arq4"
	        fi
	fi
	echo " [OK]"

done | dialog --title "Setup" --progressbox "Processando categorias selecionadas" 25 60

inseridas="$(cat $arq4)"

dialog --title "Setup" --msgbox "${inseridas:-0} categoria(s) incluída(s) com sucesso." 8 60

#removendo arquivos temporarios
rm "${arq}"
rm "${arq2}"
rm "${arq3}"
rm "${arq4}"
rm "${arq5}"
