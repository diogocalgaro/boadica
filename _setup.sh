#!/bin/bash

#config basica
source $(dirname $0)/_config.inc

#verificando se ja foi instalado
test -f ${base}/instalado && exit 0

#funcoes
source ${base}/_funcoes.inc

#iniciando
echo
echo "Script de cache do Boa Dica ${versao}"
echo
echo "Bem vindo ao script de setup. Esse script roda apenas na primeira execução e verifica se você possui os requisitos necessários pra execução, além de preparar a configuração inicial."
echo
read -p "Pressione [enter] pra continuar" r

# VERIFICANDO DEPENDENCIAS ####################################################

#bash
if [ -z "$BASH" -o "${BASH_VERSINFO:-0}" -lt 4 ]
then
	fatal "Dependência não encontrada: bash 4.x\n\nVersão atual: $(bash --version)"
fi

#dialog
which dialog > /dev/null 2>&1
if [ $? -ne 0 ]
then
	fatal "Dependência não encontrada: dialog"
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
	fatal "Nenhum dos seguintes programas de download disponíveis... $dw_opcoes"
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
	fatal "Não é foi encontrado o arquivo do banco de dados ${db} ..."
fi


# DEFININDO CATEGORIA ##########################################################

op='S'
existe=$(sqlite3 ${db} "select count(*) from categorias where id <> '0';")
if [ ${existe:-0} -eq 0 ]
then
	dialog --title "Setup" --msgbox "Na próxima tela, selecione a(s) categoria(s) do site que você deseja acompanhar. Selecione apenas os subgrupos, não selecione um grupo (eles não podem ser consultados nesse script)." 9 60
else	
	dialog --title "Setup" --yesno "Existe(m) ${existe} categoria(s) já cadastrada(s) no banco de dados. Deseja adicionar mais alguma?" 8 60
	if [ $? -ne 0 ]
	then
		op='N'
	fi
fi

if [ ${op:-S} == 'S' ]
then
	${base}/_categoria.sh

	#conferindo se realmente tem alguma categoria
	if [ ${inseridas:-0} -eq 0 ]
	then
		existe=$(sqlite3 ${db} "select count(*) from categorias where id <> '0';")
		if [ ${existe:-0} -eq 0 ]
		then
			fatal "Nenhuma categoria cadastrada no banco de dados... Recomece o setup."
		fi
	fi
fi


# CONTEUDO DA BASE DE DADOS ####################################################

n=$(sqlite3 "${db}" "select count(*) from precos;")

if [ "${n:-0}" -eq 0 ]
then
	dialog --title "Setup" --yesno "A base de dados está vazia.\nDeseja executar a rotina de carga de dados nesse momento?\nÉ possível executar mais tarde." 9 60
	if [ $? -eq 0 ]
	then
		echo "Executando rotina de carga dos dados..."
		$base/_atualizar.sh
	fi
fi


# SAINDO #######################################################################

touch ${base}/instalado
test $? -ne 0 fatal "Falha ao salvar arquivo de configuração..."
dialog --title 'Setup' --msgbox 'Setup concluído com sucesso' 7 50
