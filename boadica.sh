#!/bin/bash
################################################################################
#
# Script de consulta aos dados do site BoaDica
#
# github.com/diogocalgaro/boadica
#
################################################################################

#verificando a instalacao
$(dirname $0)/_setup.sh
test $? -ne 0 && exit $?

#dependencias
source $(dirname $0)/_config.inc
source ${base}/_funcoes.inc

#laco principal
op="P"
while [ "$op" != "S" ]
do
	#menu principal
	op=$(dialog --title "Busca Boadica ${versao}" \
		--stdout                              \
		--no-cancel                           \
		--default-item "$op"                  \
		--menu "Menu principal" 18 45 11      \
		P "Produtos"                          \
		L "Lojas"                             \
		C "Categorias"                        \
		"" "==================================="   \
		H "Carregar dados de hoje"            \
		O "Configurações"		      \
		E "Estatísticas da base de dados"     \
		A "Sobre este script"                 \
		"" "==================================="   \
		S "Sair")

	test $? -ne 0 && break
		
	case "$op" in
		"P") #produtos
			#exibindo o filtro de categorias logo no começo
			i=$(sqlite3 -csv -separator " " $db "select id, nome, consultar from categorias where id <> '0' order by 2 ${sql_limit}" | sed 's/S$/on/;s/N$/off/' | tr '\n' ' ')
			eval "categ=\$(dialog --stdout --no-cancel --checklist 'Selecione a(s) categoria(s) para consulta' 30 60 23 ${i})"

			if [ $? -eq 0 ]
			then
				categ=${categ// /,}
				sqlite3 ${db} "update categorias set consultar = 'N'; update categorias set consultar = 'S' where id in (${categ});"
			else
				continue
			fi

			op2=""
			sql_where=""
			op3="0"
			ordem_txt="fabricante, produto, categoria"
			ordem_sql="order by fabricante, prod_nome, categ_nome" 

			#configuracao de faixa de valores pra melhores ofertas
			val_min="$(sqlite3 -csv $db "select valor from configuracoes where item='oferta_valor_min';")"
			val_max="$(sqlite3 -csv $db "select valor from configuracoes where item='oferta_valor_max';")"

			while true
			do
				aguarde
				sql="select item, descricao from vw_lista_preco ${sql_where} ${ordem_sql} ${sql_limit}"
				i=$(sqlite3 -list -separator " " ${db} "${sql}")
				i=${i//$'\n'/ }
				i=${i//\'/\"}

				eval "op2=\$(dialog --stdout --no-cancel --no-tags \
					--menu 'Produtos' 30 105 23 \
					V 'Voltar' \
					B 'Buscar por um produto' \
					T 'Ver todos' \
					O 'Somente melhores ofertas (${val_min} a ${val_max})' \
					N 'Somente novidades' \
					F 'Somente favoritos' \
					D 'Consultar variações nos preços...' \
					'' '==================================================================================================' \
					S 'Trocar seleção de categorias visíveis' \
					X 'Ordenar por... (${ordem_txt})' \
					'' '==================================================================================================' \
					${i})"

				case "$op2" in
					"V") #voltar
						break ;;
					"B") #busca
						eval "pesq=\$(dialog --stdout --title 'Consultar produto' --inputbox 'Informe o nome do fabricante ou do produto' 8 60)"
						if [ $? -eq 0 -a -n "$pesq" ]
						then
							sql_where="where (fabricante like '%${pesq}%' or prod_nome like '%${pesq}%')"
						fi ;;
					"T") #todos
						sql_where='' ;;
					"O") #melhores ofertas
						sql_where="where (valorf between ${val_min} and ${val_max})" ;;
					"N") #novidades
						sql_where="where (prod_id in (select produto from vw_novos_produtos))" ;;
					"F") #favoritos
						sql_where="where (favorito = 'S')" ;;
					"D") #diferenças/variações nos preços
						aguarde
						tmp=$(mktemp)
						sqlite3 -cmd ".width 9 34 6 5 6 5 7 13" -header -column $db "select * from vw_diferencas_preco;" > $tmp
						dialog --title "Variações nos preços" --textbox $tmp 50 108
						rm ${tmp} ;;
					"S") #filtro seleção de categorias
						i=$(sqlite3 -csv -separator " " $db "select id, nome, 'off' as opcao from categorias where id <> '0' order by 2 ${sql_limit}" | tr '\n' ' ')
						eval "categ2=\$(dialog --stdout --no-cancel --checklist 'Selecione a(s) categoria(s) para consulta' 30 60 23 ${i})"
						test $? -eq 0 && categ=${categ2// /,} ;;
					"X") #ordem
						op3=$(dialog --stdout --no-cancel --no-tags --default-item ${op3} --menu 'Ordenar por' 12 45 9 0 'fabricante, produto, categoria' 1 'categoria, produto, fabricante' 2 'produto, categoria, fabricante' 3 'preco, produto, fabricante' 4 'preco, categoria, produto')
						case "${op3}" in
							"0")
								ordem_txt="fabricante, produto, categoria"
								ordem_sql="order by fabricante, prod_nome, categ_nome" ;;
							"1")
								ordem_txt="categoria, produto, fabricante"
								ordem_sql="order by categ_nome, prod_nome, fabricante" ;;
							"2")
								ordem_txt="produto, categoria, fabricante"
								ordem_sql="order by prod_nome, categ_nome, fabricante" ;;
							"3")
								ordem_txt="preco, produto, fabricante"
								ordem_sql="order by valorf, prod_nome, fabricante" ;;
							"4")
								ordem_txt="preco, categoria, produto"
								ordem_sql="order by valorf, categ_nome, prod_nome" ;;
						esac ;;
					*)
						while true
						do
							aguarde
							categ_id=${op2%;*}
							prod_id=${op2#*;}
							tmp=$(mktemp)
							tmpf=$(mktemp)
							prim=1

							sqlite3 -csv -separator "|" ${db} "select * from vw_produto where prod_id = '${prod_id}' and categ_id = '${categ_id}';" | while read r
							do
								r=${r//\"}
								IFS=$'|' read prod_id fabricante prod_nome favorito categ_id categ_nome loja_id loja_nome data valorf valor <<< "${r}"
								
								if [ ${prim:-1} -eq 1 ]
								then
									echo "Categoria: [${categ_id}] ${categ_nome}" >> $tmp
									echo "Produto: [${prod_id}] ${fabricante} - ${prod_nome}" >> $tmp
									echo "Favorito: ${favorito}" >> $tmp
									echo >> $tmp
									echo "=====================================================" >> $tmp

									#sql pra setar o favorito
									test ${favorito:-N} == 'S' && fav='N' || fav='S'
									echo "-- ${prod_id}" > $tmpf
									echo "update produtos set favorito = '${fav}' where id = '${prod_id}' and categoria = '${categ_id}';" >> $tmpf

									prim=0
								fi
							
								if [ "${data}" != "${old_data:-x}" ]
								then
									echo >> $tmp
									echo -n "${data}: " >> $tmp
									old_data="${data}"
								else
									echo -n "            " >> $tmp
								fi
								printf "%-*s" 30 "${loja_nome}" >> $tmp
								printf "%*s" 10 "R\$ ${valor}" >> $tmp
								echo >> $tmp
							done

							dialog --title 'Informações do produto' --extra-button --extra-label 'Opções' --exit-label 'Ok' --textbox "${tmp}" 50 90
							if [ $? -eq 3 ]
							then
								op3=$(dialog --stdout --no-tags --no-cancel --title 'Produto' --menu 'Opções' 10 36 7 C 'Cancelar' F 'Favoritar' G 'Gráfico de preços')
								case "${op3}" in
									"F") sqlite3 ${db} ".read $tmpf" ;;
									"G") 
										prod_id="$(head -n1 $tmpf)"
										prod_id=${prod_id//-- }
										${base}/_grafico.sh ${prod_id} ;;
								esac
							else
								break
							fi

							rm ${tmp}
							rm ${tmpf}
						done ;;
				esac
			done ;;
		"L") #lojas
			op2=""
			lojas_filtro_sql="where o.consultar='S'"

			while true
			do
				aguarde
				sql="	select id, quote(loja||'   [Itens: '||produtos||']') 
					from (
						select q.id, q.loja, count(distinct p.produto) as produtos 
						from (
							select l.id, l.nome||',   '||o.nome as loja 
							from lojas l 
							inner join locais o on (o.id = l.local)
							${lojas_filtro_sql}
						) q 
						left join precos p on (p.loja = q.id) 
						group by 1, 2
					) order by 2
					${sql_limit};"
				i=$(sqlite3 -list -separator " " ${db} "${sql}")
				i=${i//$'\n'/ }
				i=${i//\'/\"}
				eval "op2=\$(dialog --stdout --no-cancel --no-tags \
					--menu 'Lojas' 30 90 23 \
					V 'Voltar' \
					B 'Buscar por uma loja' \
					T 'Ver todas' \
					C 'Somente dos bairros selecionados' \
					'' '==============================================================================' \
					F 'Editar filtro de bairros visíveis' \
					'' '==============================================================================' \
					${i})"

				case "$op2" in
					"V") #voltar
						break ;;
					"B") #buscar loja
						eval "pesq=\$(dialog --stdout --title 'Consultar loja' --inputbox 'Informe o nome da loja' 8 60)"
						lojas_filtro_sql="where l.nome like '%$pesq%'" ;;
					"T") #ver todas
						lojas_filtro_sql="" ;;
					"C") #filtro bairros
						lojas_filtro_sql="where o.consultar='S'" ;;
					"F") #editar filtro de bairro
						i=$(sqlite3 -csv -separator " " $db "select id, nome, consultar from locais order by 2" | sed 's/S$/on/;s/N$/off/' | tr '\n' ' ')
						cod=""
						eval "cod=\$(dialog --stdout --checklist 'Locais visíveis' 30 60 23 ${i})"
		
						if [ $? -eq 0 ]
						then
							cod="$(echo $cod | sed 's/ /,/g;s/"//g')"
							sql="update locais set consultar = 'N'; update locais set consultar='S' where id in (${cod});"
							sqlite3 ${db} "${sql}"
						fi

						sql="select count(*) from locais where consultar='S';"
						res=$(sqlite3 ${db} "${sql}")
						dialog --msgbox "Localidades incluídas nas pesquisas: ${res:-0}" 7 50 ;;
					*) #ver loja
						if [ "$op2" != "V" ]
						then
							naveg_cmd="$(which $naveg_opcoes xdg-open 2>/dev/null | head -n1)"
							$naveg_cmd "${pag_vendedor}${op2}" >/dev/null 2>&1 &
						fi ;;
				esac
			done ;;
		"C") #categorias
			op2=""
			while [ "$op2" != "V" ]
			do
				aguarde
				i=$(sqlite3 -list -separator " " ${db} "select id, quote(nome||' ['||total||']') from (select c.id, c.nome, count(p.id) as total from categorias c left join produtos p on (p.categoria = c.id) where c.id <> '0' group by 1, 2 order by c.nome) ${sql_limit};")
				i=${i//$'\n'/ }
				i=${i//\'/\"}

				eval "op2=\$(dialog --stdout \
					--no-cancel \
					--menu 'Categorias selecionadas' 30 70 23 \
					V 'Voltar' \
					I 'Incluir nova categoria' \
					T 'Atualizar todas' \
					'' '===========================================' \
					${i})"

				case "$op2" in
					"I") ${base}/_categoria.sh ;;
					"T") ${base}/_atualizar.sh ;;
					[0-9]*)
						n=$(sqlite3 ${db} "select count(*) from produtos p inner join categorias c on (c.id = p.categoria) where c.id = '${op2}';")
						dialog --extra-button --extra-label "Remover" --ok-label "Ok" --cancel-label "Atualizar" --yesno "Essa categoria possui ${n} produto(s) cadastrado(s)." 7 60
						case $? in
							1) #atualizar
								backup_db
								${base}/_download.sh "$op2" ;;
							3) #remover
								dialog --yesno "Tem certeza que deseja remover essa categoria e todos os seu produtos e preços cadastrados?" 10 60
								if [ $? -eq 0 ]
								then
									aguarde
									sqlite3 ${db} "delete from precos where produto in (select id from produtos where categoria = '$op2');" && \
									sqlite3 ${db} "delete from produtos where categoria = '$op2';" && \
									sqlite3 ${db} "delete from categorias where id = '$op2';" && \
									dialog --msgbox "Categoria removida com sucesso" 6 40 || \
									dialog --msgbox "Falha ao remover categoria..." 6 40
								fi ;;
						esac ;;
				esac
			done ;;
		"H")
			${base}/_atualizar.sh ;;
		"O")
			op2=""
			tmp=$(mktemp)
			while true
			do
				sqlite3 -list ${db} "select item||'='||quote(valor) from configuracoes;" > ${tmp}
				source ${tmp}
				op2=$(dialog --stdout --no-cancel --no-tags --title 'Configurações' --menu 'Parâmetros' 10 80 7 V 'Voltar' 1 "Produtos, melhores ofertas, valor mínimo: ${oferta_valor_min}" 2 "Produtos, melhores ofertas, valor máximo: ${oferta_valor_max}")
				case "${op2}" in
					"V") break ;;
					"1") col="oferta_valor_min" ;;
					"2") col="oferta_valor_max" ;;
				esac
				atual=$(sqlite3 ${db} "select valor from configuracoes where item = '${col}' limit 1")
				novo=$(dialog --stdout --inputbox 'Informe o novo valor:' 8 50 "${atual}")
				if [ "${atual}" != "${novo}" ]
				then
					sqlite3 ${db} "update configuracoes set valor = '${novo}' where item = '${col}';"
				fi
			done
			rm ${tmp}
			;;
		"E")
			tmp="$(mktemp)"
			while true
			do
				aguarde
				sqlite3 -cmd ".width 48" -header -column $db "select * from vw_estatisticas;" > "$tmp"
				dialog --title "Estatísticas da base de dados" --extra-button --extra-label 'Resetar BD' --ok-label 'Ok' --textbox ${tmp} 16 60
				out=$?
				if [ $out -eq 0 ]
				then
					break
				elif [ $out -eq 3 ]
				then
					dialog --title 'Confirmação' --yesno "Tem certeza que deseja resetar a base de dados?\n\nEssa opção vai criar um novo arquivo ${db} a partir da estrutura do arquivo atual, porém não manterá as informações salvas atualmente (categorias, lojas, produtos e preços).\n\nEssa operação não pode ser desfeita." 12 70
					if [ $? -eq 0 ]
					then
						tput setf 4
						echo "[Recriando base de dados]"

						tput setf 1
						echo "Fazendo dump da base de dados atual..."
						sqlite3 ${db} .dump | grep -v '^INSERT INTO' | grep -v '^COMMIT' > "${db}-dump"
						echo "INSERT INTO locais (id, nome, consultar) VALUES ('0', 'Desconhecido', 'S');" >> "${db}-dump"
						echo "INSERT INTO categorias (id, nome, url) VALUES ('0', 'Desconhecida', '/pesquisa/precos');" >> "${db}-dump"
						echo "INSERT INTO configuracoes (item, valor) VALUES ('versao_bdados', '2.0');" >> "${db}-dump"
						echo "INSERT INTO configuracoes (item, valor) VALUES ('oferta_valor_min', '0');" >> "${db}-dump"
						echo "INSERT INTO configuracoes (item, valor) VALUES ('oferta_valor_max', '100');" >> "${db}-dump"
						echo "COMMIT;" >> "${db}-dump"

						echo "Criando nova base de dados..."
						sqlite3 -bail "${db}-novo" ".read ${db}-dump"
						if [ $? -eq 0 ]
						then
							echo "Substituindo os arquivos"
							rm -fv "${db}-dump"
							rm -fv "${db}"
							mv -v "${db}-novo" "${db}"
							echo "Operação concluída com sucesso."
						else
							echo "Ocorreu alguma falha, porém a base atual foi mantida."
							exit 1
						fi

						tput sgr0
						read -p "Pressione [ENTER] pra continuar" r
					fi
				fi
			done
			rm "$tmp" ;;
		"A")
			dialog --title 'Sobre...' --ok-label 'Fechar' --extra-button --extra-label 'Licença' --textbox ${base}/ABOUT 25 60
			if [ $? -eq 3 ]
			then
				dialog --title 'Licença' --textbox ${base}/LICENSE 30 70
			fi ;;
	esac
done

tput clear
