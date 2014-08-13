#!/bin/bash

#config basica
source $(dirname $0)/config.inc

#funcoes
source ${base}/funcoes.inc

#backup do banco de dados
backup_db

#obtendo as categorias cadastradas
sqlite3 ${db} "select id, nome, url from categorias where id <> '0' order by id;" | while read i
do
	id=${i%%|*}
	nome=${i%|*}
	nome=${nome#*|}
	url=${site}${i##*|}

	tput setf 2
	echo
	echo "Categoria: ${id} ${nome}"
	echo "URL: ${url}"
	echo
	tput sgr0

	${base}/obter_dados.sh "${id}" "${url}"

	echo
	echo "------------------------------"
done

echo
