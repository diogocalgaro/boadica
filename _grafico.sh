#!/bin/bash

#dependencias
source $(dirname $0)/_config.inc
source ${base}/_funcoes.inc

#verificacoes
prod_id="$1"
if [ -z "${prod_id}" ]
then
	fatal "o ID do produto não foi informado..."
fi
if [ -z "${arq_svg}" ]
then
	fatal "Erro: arquivo de saída de imagem não encontrado..."
fi

#arquivos temporarios
arq0="$(mktemp)"
arq1="$(mktemp)"

#consultando info do produto
sql="select fabricante||' - '||nome from produtos where id = '${prod_id}'"
sqlite3 ${db}  "${sql}" > "$arq0"
produto="$(cat $arq0)"

#variaveis
limx=600
limy=600
zerox=25
zeroy=$(( limy - 25 ))
teto=40
marg=5
topo=$zeroy
esq=$zerox
dist=50
topo_txt=$(( zeroy + 10 ))
esq_txt=$(( zerox - 5 ))
max_val=200

#consultando precos
sql="select data, strftime('%d/%m', data) as dataf, round(valor,0) as valorf \
from ( \
	select data, min(valor_num) as valor \
	from precos \
	where produto = '${prod_id}' \
	group by 1 \
	order by 1 desc \
	limit 10 \
) q \
order by 1;"

#gerando começo do arquivo svg
cat > ${arq_svg} <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="${limx}" height="${limy}">
	<desc>Grafico de testes 1</desc>
	<title>Gráfico</title>

	<defs>
		<g id="antes">
			<!-- eixo x -->
			<line x1="${zerox}" y1="${zeroy}" x2="$(( limx - 25 ))" y2="${zeroy}" stroke-width="2" stroke="black" />
			<polygon points="$(( limx - marg )),${zeroy} $(( limx - marg - 20 )),$(( zeroy + 10 )) $(( limx - marg - 20 )),$(( zeroy - 10 ))" stroke="black" />

			<!-- eixo y -->
			<line x1="${zerox}" y1="${zeroy}" x2="${zerox}" y2="25" stroke-width="2" stroke="black" />
			<polygon points="${zerox},${marg} $(( zerox + 10 )),$(( marg + 20 )) $(( zerox - 10 )),$(( marg + 20 ))" stroke="black" />

			<!-- dados -->
			<text x="40" y="20" font-family="serif, Liberation Serif, MS Sans Serif" font-size="12" fill="blue">${produto}</text>
EOF

#gerando meio do arquivo svg
while read i
do
	dataf="${i#*;}"
	dataf="${dataf%;*}"
	valorf="${i##*;}"
	valorf="${valorf//.0}"
	topo=$(( zeroy - valorf ))
	test ${topo:-0} -lt ${teto} && topo=${teto}
	test ${valorf:-0} -gt ${max_val:-0} && max_val=${valorf}
	echo -n "${esq},${topo} " >> "$arq1"

cat >> ${arq_svg} <<EOF
			<circle cx="${esq}" cy="${topo}" r="4" fill="black" stroke="none" stroke-width="0" />
			<text x="${esq}" y="$(( topo - 5 ))" font-family="serif, Liberation Serif, MS Sans Serif" font-weight="bold" font-size="10" fill="green">${valorf}</text>
			<text x="${esq_txt}" y="${topo_txt}" font-family="serif, Liberation Serif, MS Sans Serif" font-size="9" fill="black">${dataf}</text>
EOF

	esq=$(( esq + dist ))
	esq_txt=$(( esq_txt + dist ))
done < <(sqlite3 -csv -separator ';' ${db} "${sql}")

esq="$(awk '{ print $NF }' $arq1 | awk -F ',' '{ printf $1 }')"
echo -n "${esq},${zeroy} ${zerox},${zeroy}" >> "$arq1"
pontos="$(cat ${arq1})"

#final do arquivo svg
cat >> ${arq_svg} <<EOF
		</g>
	</defs>

	<!-- fundo cor solida -->
	<rect width="${limx}" height="${limy}" style="fill:rgb(255,255,255)" />

	<!-- grafico -->
	<polygon fill="#FFFACA" stroke-width="0" stroke="red" points="${pontos}" />

	<!-- desenhando elementos salvos para ficar no topo -->
	<use xlink:href="#antes" />
</svg>
EOF

#removendo arquivos temporarios
rm "${arq0}"
rm "${arq1}"

#procurando um visualizador de imagens svg
view_cmd="$(which $view_opcoes xdg-open 2>/dev/null | head -n1)"
if [ -z "${view_cmd}" ]
then
        fatal "ERRO: Não foi possível encontrar um programa para abrir .svg"
fi
${view_cmd} ${arq_svg}
