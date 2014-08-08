#arquivo com funcoes comuns

function fatal {
	tput setf 4
	echo -e "ERRO FATAL: ${1}"
	tput sgr0
	exit 1
}

function backup_db {
	echo -n "Fazendo backup da base atual... "
	rm ${db}.gz 2>/dev/null
	gzip -k --fast ${db}
	test $? -eq 0 && echo "[OK]" || echo "[Falhou]"
}
