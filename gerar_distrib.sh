#!/bin/bash

#config
source config.inc

#recuperando o dump
if [ -f "$db" ]
then
	#dump da estrutura de desenvolvimento
        sqlite3 "$db" .dump | grep -v '^INSERT INTO' | grep -v '^COMMIT' > "${dump}"

	#inserindo dados padrao
	echo "INSERT INTO locais (id, nome, consultar) VALUES ('0', 'Desconhecido', 'S');" >> "${dump}"
	echo "INSERT INTO categorias (id, nome, url) VALUES ('0', 'Desconhecida', '/pesquisa/precos');" >> "${dump}"
	echo "INSERT INTO configuracoes (item, valor) VALUES ('versao_bdados', '2.0');" >> "${dump}"
	echo "INSERT INTO configuracoes (item, valor) VALUES ('oferta_valor_min', '0');" >> "${dump}"
	echo "INSERT INTO configuracoes (item, valor) VALUES ('oferta_valor_max', '100');" >> "${dump}"
	echo "COMMIT;" >> "${dump}"

        echo "Estrutura da base de dados recuperada com sucesso em ${dump}"
fi

#apagando arquivos antigos
rm -rf distrib/*

#copiando arquivos novos
echo "Copiando arquivos:"
cp -v boadica.sh config.inc funcoes.inc dados.dump obter_dados.sh criar_grafico.sh setup.sh incluir_categoria.sh atualizar_todas.sh  distrib/
touch distrib/"$(basename $arq_svg)"

#removendo categoria padrao
sed -i '/^instalado/d' distrib/config.inc
echo 'instalado="N"' >> distrib/config.inc

#gerar arquivo compactado pra distribuicao (parametro "-zip")
if [ "$1" == "-zip" ]
then
	z="script-boadica-${versao}.tar.gz"
	rm "$z" > /dev/null 2>&1
	tar czvf "$z" distrib/*
	chmod 666 "$z"
	echo
	echo "Criado $z"
fi
