#!/bin/bash

#dependencias
source $(dirname $0)/_config.inc
source ${base}/_funcoes.inc

#parametro
p="$1"
test -z "${p}" && fatal "É preciso informar parte do nome do produto para fazer a busca"

#executando consulta com saida direta pro terminal
i=""
x=0
echo
echo "Consulta rápida de produtos"
echo "==========================="
echo

while read i
do
	(( x++ ))

	if [ ${x} -eq 3 ]
	then
		tput setf 1
		echo -e "${i}"
		tput sgr0
	else
		echo -e "${i}"
	fi

done < <(sqlite3 -header -column -cmd '.width 17 15 30 11 7 16 32' ${db} "\
select c.nome as categoria, p.fabricante, p.nome as produto, r.data, r.valor_str as preco, l.nome as loja, o.nome as local \
from produtos p \
inner join categorias c on (c.id = p.categoria) \
inner join precos r on (r.produto = p.id) \
inner join lojas l on (l.id = r.loja) \
inner join locais o on (o.id = l.local and o.consultar = 'S') \
where p.nome like '%${p}%' and r.data >= date('now', '-3 days') \
order by c.nome, p.fabricante, p.nome, r.data desc, r.valor_num, l.nome \
limit 40")

#rodape
test ${x:-0} -eq 0 && echo "Nenhum produto encontrado com esse nome." || echo -e "\n$(( x -2 )) item(ns) (limite 40)"
echo
