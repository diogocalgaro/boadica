#!/bin/bash

#config
source config.inc

#recuperando o dump
if [ -f "$db" ]
then
	#dump da estrutura de desenvolvimento
        sqlite3 "$db" .dump | grep -v '^INSERT INTO' | grep -v '^COMMIT' > "${base}/${dump}"

	#inserindo dados padrao
	echo "INSERT INTO locais (id, nome, consultar) VALUES ('0', 'Desconhecido', 'S');" >> "${base}/${dump}"
	echo "COMMIT;" >> "${base}/${dump}"

        echo "Estrutura da base de dados recuperada com sucesso em ${base}/${dump}"
fi

#apagando arquivos antigos
rm -rf distrib/*

#copiando arquivos novos
echo "Copiando arquivos:"
cp -v boadica.sh config.inc dados.dump obter_dados.sh criar_grafico.sh setup.sh distrib/
touch distrib/"$(basename $arq_svg)"

#removendo categoria padrao
sed -i '/^categ=/d;/^url_dados=/d;/^instalado/d' distrib/config.inc
echo 'categ=""' >> distrib/config.inc
echo 'url_dados=""' >> distrib/config.inc
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
