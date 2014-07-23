#!/bin/bash

#config
output_dir="/Work/backup"

#removendo backups antigos, mantendo apenas um
echo "Removendo backups antigos..."
num=$(ls -lh ${output_dir}/boadica* | wc -l )
if [ "${num:-0}" -gt 3 ]
then
	find ${output_dir}/ -mindepth 1 -maxdepth 1 -type f -name "boadica*" | sort | head -n-3 | while read i
	do
		rm -v "$i"
	done
fi

echo

#gerando novo backup
echo "Gerando novo backup..."
tar cJvf ${output_dir}/boadica_$(date +%Y-%m-%d_%Hh%M).tar.xz $(find . -maxdepth 1 -type f ! -name '*.gz' ! -name '*.tar*' | sort | xargs)

echo
echo "Pronto."
