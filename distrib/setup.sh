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
	if [ -f "$base/$dump" ]
	then
		#criando nova base de dados
		rm "$db" 2> /dev/null
		sqlite3 -bail "$db" ".read ${base}/${dump}"

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

        which curl > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
                curl --compressed -s -o "$arq" "$url_base"
        else
                which aria2c > /dev/null 2>&1
                if [ $? -eq 0 ]
                then
                        aria2c -q -o "$arq" "$url_base"
                else
                        which wget > /dev/null 2>&1
                        if [ $? -eq 0 ]
                        then
                                wget -q -O "$arq" --no-use-server-timestamps "$url_base"
                        else
                                fatal "Nenhum programa de download disponível..."
                        fi
                fi
        fi

	if [ ! -s "$arq" ]
	then
		fatal "Não conseguiu baixar o arquivo: ${url_base}"
	fi

	#parseando a pagina
	linha1=$(grep -nw -m1 '<div class="menu-dropdown-topo">' "$arq" | cut -d':' -f1)
	linha2=$(grep -nw -m1 '<li><a href="/iniciodrivers.asp">Drivers</a></li>' "$arq" | cut -d':' -f1)
	dif="$((linha2 - linha1))"
	head -n${linha2} "$arq" | tail -n${dif} | iconv -f "ISO-8859-1" -t "UTF-8" | sed 's/^[ \t]*//' > "$arq2"
	num_linhas="$(wc -l $arq2 | awk '{ print $1 }')"

	#montando as opcoes pro menu
	while read i
	do
		echo "$i" | grep '/pesquisa/' 2>&1 >/dev/null
		if [ $? -eq 0 ]
		then
			linha="$(echo "$i" | tr -d '\r\n')"
			linha="$(echo "$linha" | sed 's/^ *//;s/ *$//;s/<li><a href=//')"
			tipo=""

			echo "$i" | grep '</li>' 2>&1 >/dev/null
			if [ $? -eq 1 ]
			then
				tipo="c"
			else
				tipo="s"
			fi

			linha="$(echo "$linha" | sed 's,</a>,,;s,</li>,,;s/\"$//;s/\" ou/ ou/;s/$/\"/')"

			if [ "$tipo" == "c" ]
			then
				linha="$(echo "$linha" | sed 's/>/\|\"┣━━━━━━━━━━/')"
				cod='"C"'
			else
				linha="$(echo "$linha" | sed 's/>/\|\"┣/')"
				cod="$(echo "$linha" | cut -d'|' -f1)"
			fi

			desc="$(echo "$linha" | cut -d'|' -f2)"
			echo "$cod $desc " >> "$arq3"
		fi

		#barra de progresso
		(( x++ ))
		perc=$(echo "scale=2;${x}/${num_linhas}*100" | bc)
		perc=$(echo "${perc}/1" | bc)
		echo $perc

	done < "$arq2" | whiptail --title "Setup" --gauge "Montando o menu de opções" 7 50 0

	#perguntando a categoria
	while [ -z "${url_dados}" -o "${url_dados}" == "C" ]
	do
		eval "url_dados=\$(whiptail --nocancel --notags --title 'Setup' --menu 'Selecione a categoria que deseja utilizar' 50 100 38 $(cat $arq3 | tr -d '\n') 3>&2 2>&1 1>&3)"
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
