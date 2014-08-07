#!/bin/bash

#config basica
source $(dirname $0)/config.inc

#verificando se ja foi instalado
if [ "${instalado:-N}" == "S" ]
then
	exit 0
fi

#funcoes
function fatal {
	tput setf 4
	echo -e "ERRO FATAL: $1"
	tput sgr0
	exit 1
}


# VERIFICANDO DEPENDENCIAS ####################################################

#bash
if [ -z "$BASH" -o "${BASH_VERSINFO:-0}" -lt 4 ]
then
	fatal "Dependência não encontrada: bash 4.x\n\nVersão atual: $(bash --version)"
fi

#whiptail
which whiptail > /dev/null 2>&1
if [ $? -ne 0 ]
then
	fatal "Dependência não encontrada: whiptail"
fi

#resize
which resize > /dev/null 2>&1
if [ $? -ne 0 ]
then
	fatal "Dependência não encontrada: resize (pacote xterm)"
fi

#gzip
which gzip > /dev/null 2>&1
if [ $? -ne 0 ]
then
	fatal "Dependência não encontrada: gzip"
fi

#sqlite
which sqlite3 > /dev/null 2>&1
if [ $? -ne 0 ]
then
	fatal "Dependência não encontrada: sqlite3"
fi
sql_ver="$(sqlite3 -version | awk '{ print $1 }')"
maj_ver="$(echo $sql_ver | cut -d'.' -f1)"
min_ver="$(echo $sql_ver | cut -d'.' -f2)"
verif_ver="${maj_ver}${min_ver}"
if [ ! "${verif_ver}" -ge "36" ]
then
        fatal "Sqlite3 abaixo da versão mínima: 3.6.x\nVersão atual: $(sqlite3 -version)"
fi

#downloader
dw="$(which $dw_opcoes 2>/dev/null | head -n1)"
if [ -n "$dw" ]
then
	dw="$(basename $dw)"
else
	fatal "Nenhum programa de download disponível..."
fi


# DIRETORIO DE TRABALHO PARA DOWNLOADS #########################################
if [ ! -d "${workdir}" ]
then
	mkdir "${workdir}"
	if [ $? -ne 0 ]
	then
		fatal "Falha ao criar o diretório de trabalho: ${workdir}"
	fi
fi
perm="$(stat --printf=%a ${workdir})"
if [ "${perm}" -lt 700 ]
then
	chmod u+rwx ${workdir}
	if [ $? -ne 0 ]
	then
		fatal "Falha ao definir permissões do diretório de trabalho..."
	fi
fi


# BASE DE DADOS ################################################################

if [ ! -s "${db}" ]
then
	#confirmacao
	whiptail --title "Setup" --yesno "Não foi encontrado o arquivo de banco de dados.\nDeseja criá-lo agora?" 8 55

	if [ $? -ne 0 ]
	then
		fatal "Não é possível continuar sem uma base de dados disponível..."
	fi

	#verificando sqls de criacao da base
	if [ -f "$dump" ]
	then
		#criando nova base de dados
		rm "$db" 2> /dev/null
		sqlite3 -bail "$db" ".read ${dump}"

		if [ $? -eq 0 ]
		then
			whiptail --title "Setup" --msgbox "Base de dados criada com sucesso." 7 40
		else
			fatal "Não foi possível criar a base de dados..."
		fi
	else
		fatal "Não foi possível criar a base de dados. Não está disponível o arquivo de dump (${dump})..."
	fi
fi


# DEFININDO CATEGORIA ##########################################################

if [ -z "$categ" -o -z "$url_dados" ]
then
	#confirmacao
	whiptail --title "Setup" --yesno "A categoria de produtos que o script consulta não está definida.\nDeseja selecioná-la agora?" 8 70

	if [ $? -ne 0 ]
	then
		fatal "Não é possível continuar sem uma categoria definida..."
	fi

	#variaveis
	arq="$(mktemp)"
	arq2="$(mktemp)"
	arq3="$(mktemp)"
	url_dados=""
	x=0

	#baixando a pagina
	echo "Obtendo página inicial da pesquisa de preços..."
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
	echo "Montando o menu de opções..."
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
		echo "$cod $desc " >> "$arq3"

	done < "$arq2"

	#perguntando a categoria
	while [ -z "${url_dados}" -o "${url_dados}" == "C" ]
	do
		eval "url_dados=\$(whiptail --nocancel --notags --title 'Setup' --menu 'Selecione a categoria que deseja utilizar' 40 100 28 $(cat $arq3 | tr -d '\n') 3>&2 2>&1 1>&3)"
	done

	#obtendo o nome da categoria
	categ="$(grep -m1 "$url_dados" "$arq3" | awk -F'" "' '{ print $2 }' )"
	categ="${categ:1}"
	categ="$(echo "$categ" | sed 's/\"//')"
	categ="$(echo "$categ" | sed 's/^ *//;s/ *$//')"

	#salvando configuracoes
	sed -i '/^categ=/d;/^url_dados=/d' config.inc
	echo "categ=\"${categ}\"" >> config.inc
	echo "url_dados=\"\${site}${url_dados}\"" >> config.inc
	whiptail --title "Setup" --msgbox "Categoria selecionada com sucesso." 7 50

	#removendo arquivos temporarios
	rm "$arq"
	rm "$arq2"
	rm "$arq3"
fi


# CONTEUDO DA BASE DE DADOS ####################################################

n=$(sqlite3 "${db}" "select count(*) from precos;")

if [ "${n:-0}" -eq 0 ]
then
	whiptail --title "Setup" --yesno "A base de dados está vazia.\nDeseja executar a rotina de carga de dados nesse momento?\nÉ possível executar mais tarde." 9 70
	if [ $? -eq 0 ]
	then
		echo "Executando rotina de carga dos dados..."
		$base/obter_dados.sh
	fi
fi


# SAINDO #######################################################################

sed -i '/^instalado/d' config.inc
echo 'instalado="S"' >> config.inc

if [ -z "$1" ] #se for rodado diretamente por ./setup.sh
then
	echo "Setup concluído com sucesso."
	echo
fi
