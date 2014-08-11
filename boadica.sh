#!/bin/bash
################################################################################
#
# Script de consulta aos dados do site BoaDica
#
# github.com/diogocalgaro/boadica
#
################################################################################

#verificando a instalacao
$(dirname $0)/setup.sh x #se o script receber algum parametro ele sabe que foi chamado por outro script
test $? -ne 0 && exit $?

#config basica
source $(dirname $0)/config.inc

#config local
sql_limit="limit 1000" #maximo de resultado numa query sql

#funcoes
source ${base}/funcoes.inc

#laco principal
op="P"
while [ "$op" != "S" ]
do
	#menu principal
	op=$(dialog --title "Busca Boadica ${versao}" \
		--stdout                              \
		--no-cancel                           \
		--default-item "$op"                  \
		--menu "Menu principal" 16 45 9       \
		P "Produtos"                          \
		L "Lojas"                             \
		C "Categorias"                        \
		"" "=============================="   \
		H "Carregar dados de hoje"            \
		E "Estatísticas da base de dados"     \
		A "Sobre este script"                 \
		"" "=============================="   \
		S "Sair")

	test $? -ne 0 && break
		
	case "$op" in
		"P") #produtos
			prod_filtro=1
			categ_filtro_item=''
			prod_filtro_txt="Ver todos os produtos (DESATIVAR TODOS OS FILTROS)"
			op2=""

			while [ "$op2" != "V" ]
			do
				prod_filtro_sql="where c.id in (${categ_filtro_item}-1)"

				i=$(sqlite3 -list -separator " " ${db} "select quote(c.id||';'||p.id), quote('['||c.nome||']  '||p.fabricante||'  -  '||p.nome) from produtos p inner join categorias c on (c.id = p.categoria) ${prod_filtro_sql} order by c.nome, p.fabricante, p.nome ${sql_limit};")
				i=${i//$'\n'/ }
				i=${i//\'/\"}

				eval "op2=\$(dialog --stdout --no-cancel --no-tags \
					--menu 'Produtos' 30 90 23 \
					V 'Voltar' \
					B 'Buscar por uma produto' \
					T '"${prod_filtro_txt}"' \
					F 'Editar filtro de categorias visíveis' \
					'' '==============================================================================' \
					${i})"

				case "$op2" in
					"B") #busca
						eval "pesq=\$(dialog --stdout --title 'Consultar produto' --inputbox 'Informe o nome do fabricante ou do produto' 8 60)"
						if [ $? -eq 0 -a -n "$pesq" ]
						then
							prod_filtro=1
							categ_filtro_item='-1'
							prod_filtro_txt="Ver todos os produtos (DESATIVAR TODOS OS FILTROS)"
							prod_filtro_sql="where c.id in (${categ_filtro_item}-1) and (p.fabricante like '%{pesq}%' or p.nome like '%{pesq}%')"
						fi ;;
					"T") #ver todos
						if [ $prod_filtro -eq 1 ]
						then
							prod_filtro=0
							categ_filtro_item='-1'
							prod_filtro_txt="Ver somente os produtos das categorias selecionadas (ATIVAR FILTRO DE CATEGORIA)"
							prod_filtro_sql=""
						else
							prod_filtro=1
							categ_filtro_item='-1'
							prod_filtro_txt="Ver todos os produtos (DESATIVAR TODOS OS FILTROS)"
							prod_filtro_sql="where c.id in (${categ_filtro_item}-1)'"
						fi ;;
					"F") #filtro
						i=$(sqlite3 -csv -separator " " $db "select id, nome, 'off' as opcao from categorias where id <> '0' order by 2 ${sql_limit}" | tr '\n' ' ')
						cod=""
						eval "cod=\$(dialog --stdout --checklist 'Categorias visíveis' 30 60 23 ${i})"
		
						if [ $? -eq 0 ]
						then
							cod=${cod// /,}
							test -n "${cod}" && cod=${cod}','
							categ_filtro_item="${cod}"
						fi
					;;
				esac
			done ;;
		"L") #lojas
			lojas_filtro=1
			lojas_filtro_txt="Ver todas as lojas (DESATIVAR TODOS OS FILTROS)"
			lojas_filtro_sql="where o.consultar='S'"
			op2=""

			while [ "$op2" != "V" ]
			do
				i=$(sqlite3 -list -separator " " ${db} "select id, quote(loja||'   ['||produtos||']') from (select q.id, q.loja, count(distinct p.produto) as produtos from (select l.id, l.nome||',   '||o.nome as loja from lojas l inner join locais o on (o.id = l.local) ${lojas_filtro_sql}) q left join precos p on (p.loja = q.id) group by 1, 2) order by 2 ${sql_limit};")
				i=${i//$'\n'/ }
				i=${i//\'/\"}

				eval "op2=\$(dialog --stdout --no-cancel --no-tags \
					--menu 'Lojas' 30 90 23 \
					V 'Voltar' \
					B 'Buscar por uma loja' \
					T '"${lojas_filtro_txt}"' \
					F 'Editar filtro de bairros visíveis' \
					'' '==============================================================================' \
					${i})"

				case "$op2" in
					"B") #buscar loja
						eval "pesq=\$(dialog --stdout --title 'Consultar loja' --inputbox 'Informe o nome da loja' 8 60)"
						if [ $? -eq 0 -a -n "$pesq" ]
						then
							lojas_filtro=1
							lojas_filtro_txt="Ver todas as lojas (DESATIVAR FILTRO DE BUSCA)"
							lojas_filtro_sql="where l.nome like '%$pesq%'"
						fi ;;
					"T") #ver todas as lojas, sem filtro
						if [ $lojas_filtro -eq 1 ]
						then
							lojas_filtro=0
							lojas_filtro_txt="Ver somente as lojas dos bairros selecionados (ATIVAR FILTRO DE BAIRROS)"
							lojas_filtro_sql=""
						else
							lojas_filtro=1
							lojas_filtro_txt="Ver todas as lojas (DESATIVAR TODOS OS FILTROS)"
							lojas_filtro_sql="where o.consultar='S'"
						fi ;;
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
					"I") ${base}/incluir_categoria.sh ;;
					"T") ${base}/atualizar_todas.sh ;;
					[0-9]*)
						n=$(sqlite3 ${db} "select count(*) from produtos p inner join categorias c on (c.id = p.categoria) where c.id = '${op2}';")
						dialog --extra-button --extra-label "Remover" --ok-label "Ok" --cancel-label "Atualizar" --yesno "Essa categoria possui ${n} produto(s) cadastrado(s)." 7 60
						case $? in
							1) #atualizar
								backup_db
								${base}/obter_dados.sh "$op2" ;;
							3) #remover
								dialog --yesno "Tem certeza que deseja remover essa categoria e todos os seu produtos e preços cadastrados?" 10 60
								if [ $? -eq 0 ]
								then
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
			${base}/atualizar_todas.sh ;;
		"E")
			tmp="$(mktemp)"
			sqlite3 -cmd ".width 48" -header -column $db "select * from vw_obter_estatisticas;" > "$tmp"
			dialog --title "Estatísticas da base de dados" --textbox $tmp 16 60
			rm "$tmp" ;;
		"A")
			dialog --title "Sobre..." --textbox ${base}/ABOUT.md 25 60 ;;
	esac


done

tput clear

exit 0
#############################################################################

#laço principal
while [ "$op" != "S" ]
do
	#menu principal
	op=$(whiptail --title "Busca Boadica ${versao} (Categoria: ${categ})" \
		--menu "Menu principal" 25 60 16 \
		B " Buscar item em todas as lojas" \
		I " Consultar itens de uma loja" \
		D " Consultar diferenças de preço" \
		L " Consultar informações de uma loja" \
		O " Consultar melhores ofertas" \
		N " Consultar novidades" \
		T " Listar todos os itens" \
		F " Acompanhar favoritos" \
		"" " =================================" \
		C " Carregar dados de hoje..." \
		E " Estatísticas da base de dados"  \
		"" " =================================" \
		V " Configurar localidades visíveis" \
		P " Configurar produtos favoritos" \
		"" " =================================" \
		S " Sair" 3>&2 2>&1 1>&3)

	if [ $? -ne 0 ]
	then
		break
	fi

	#ações do menu principal
	if [ "$op" == "B" ]
	then
		p=$(whiptail --title "Buscar item" --inputbox "Informe as palavras para pesquisa do item" $alt_jan_pq $larg_jan_pq 3>&2 2>&1 1>&3)
		if [ $? -eq 0 -a -n "$p" ]
		then
			cod=""
			i=$(sqlite3 -csv $db "select id, descricao from vw_buscar_item_ultimo_preco_2col where produto like '%${p}%';" | tr '\n' ' ' | tr ',' ' ')
			i="${i} ' ' ' ' Voltar =============================="

			while [ "$cod" != "Voltar" ]
			do
				eval "cod=\$(whiptail --default-item "${cod:-0}" --nocancel --menu 'Produtos encontrados' $alt_jan_gr $larg_jan_gr $menu_jan_gr ${i} 3>&2 2>&1 1>&3)"

				if [ "$cod" != "Voltar" ]
				then
					$base/criar_grafico.sh $cod
				fi
			done
		fi
	elif [ "$op" == "I" ]
	then
		p=$(whiptail --title "Consultar itens" --inputbox "Informe o nome da loja" $alt_jan_pq $larg_jan_pq 3>&2 2>&1 1>&3)
		if [ $? -eq 0 -a -n "$p" ]
		then
			tmp=$(mktemp)
			sqlite3 -cmd ".width 20 35 8 17 10" -header -column $db "select * from vw_buscar_por_loja where Loja like '%${p}%';" > $tmp
			whiptail --title "Consultar itens da loja" --scrolltext --textbox $tmp $alt_jan_gr $larg_jan_gr
			rm $tmp
		fi
	elif [ "$op" == "C" ]
	then
		echo "Executando rotina de carga dos dados..."
		$base/obter_dados.sh
	elif [ "$op" == "D" ]
	then
		tmp=$(mktemp)
		sqlite3 -cmd ".width 9 34 6 5 6 5 7 13" -header -column $db "select * from vw_diferenca_preco;" > $tmp
		whiptail --title "Diferenças de preço" --scrolltext --textbox $tmp $alt_jan_gr $larg_jan_gr
		rm $tmp
	elif [ "$op" == "O" ]
	then
		cod=""
		val_min="$(sqlite3 -csv $db "select valor from configuracoes where item='oferta_valor_min';")"
		val_max="$(sqlite3 -csv $db "select valor from configuracoes where item='oferta_valor_max';")"

		while [ "$cod" != "Voltar" ]
		do
			eval "cod=\$(whiptail --notags --menu 'Menu melhores ofertas' $alt_jan_md $larg_jan_md $menu_jan_md Ver \"Ver listagem das melhores ofertas\" Min \"[Config] Valor mínimo = $val_min\" Max \"[Config] Valor máximo = $val_max\" Voltar \"Voltar ====================\" 3>&2 2>&1 1>&3)"

			if [ "$cod" == "Ver" ]
			then
				tmp=$(mktemp)
				sqlite3 -cmd ".width 18 48 20 8" -header -column $db "select * from vw_melhores_ofertas;" > $tmp
				whiptail --title "Lista das melhores ofertas" --scrolltext --textbox $tmp $alt_jan_gr $larg_jan_gr
				rm $tmp
				cod="Voltar" #voltar direto pro menu principal
			elif [ "$cod" == "Min" ]
			then
				v="$(whiptail --title "Configuração" --inputbox "Indique o valor mínimo:" $alt_jan_pq $larg_jan_pq 3>&2 2>&1 1>&3)"
				val_min="${v:-0}"
				sqlite3 $db "update configuracoes set valor='$val_min' where item='oferta_valor_min';"
			elif [ "$cod" == "Max" ]
			then
				v="$(whiptail --title "Configuração" --inputbox "Indique o valor máximo:" $alt_jan_pq $larg_jan_pq 3>&2 2>&1 1>&3)"
				val_max="${v:-0}"
				sqlite3 $db "update configuracoes set valor='$val_max' where item='oferta_valor_max';"
			fi
		done
	elif [ "$op" == "N" ]
	then
		tmp=$(mktemp)
		sqlite3 -cmd ".width 18 48 20 8" -header -column $db "select * from vw_novidades;" > $tmp
		whiptail --title "Novidades" --scrolltext --textbox $tmp $alt_jan_gr $larg_jan_gr
		rm $tmp
	elif [ "$op" == "L" ]
	then
		l=$(whiptail --title "Consultar Loja" --inputbox "Informe o nome da loja" $alt_jan_pq $larg_jan_pq 3>&2 2>&1 1>&3)
		if [ $? -eq 0 -a -n "$l" ]
		then
			i=$(sqlite3 -csv $db "select id, nome||' ('||localizacao||')' as item from tb_lojas where nome like '%${l}%';" | tr '\n' ' ' | tr ',' ' ')

			eval "cod=\$(whiptail --notags --menu 'Selecione a loja' $alt_jan_gr $larg_jan_gr $menu_jan_gr ${i} 3>&2 2>&1 1>&3)"
			if [ -n "$cod" ]
			then
				naveg_cmd="$(which $naveg_opcoes xdg-open 2>/dev/null | head -n1)"
				$naveg_cmd "${pag_vendedor}${cod}" >/dev/null 2>&1 &
			fi
		fi
	elif [ "$op" == "E" ]
	then
		tmp=$(mktemp)
		sqlite3 -cmd ".width 48" -header -column $db "select * from vw_obter_estatisticas;" > $tmp
		whiptail --title "Estatísticas da base de dados" --textbox $tmp $alt_jan_md $larg_jan_md
		rm $tmp
	elif [ "$op" == "T" ]
	then
		cod=""
		i="Voltar ============================== ' ' ' '"
		j=$(sqlite3 -csv $db "select id, item from vw_obter_lista_produtos;" | tr '\n' ' ' | tr ',' ' ')
		i="${i} ${j} ' ' ' ' Voltar =============================="

		while [ "$cod" != "Voltar" ]
		do
			eval "cod=\$(whiptail --default-item "${cod:-0}" --nocancel --menu 'Todos os produtos' $alt_jan_gr $larg_jan_gr $menu_jan_gr ${i} 3>&2 2>&1 1>&3)"

			if [ "$cod" != "Voltar" ]
			then
				$base/criar_grafico.sh $cod
			fi
		done
	elif [ "$op" == "F" ]
	then
		cod=""
		i=$(sqlite3 -csv $db "select id, substr(descricao,1,$col_jan_gr) from vw_buscar_favorito_id;" | tr '\n' ' ' | tr ',' ' ')
		i="${i} ' ' ' ' Voltar 'Voltar =============================='"

		while [ "$cod" != "Voltar" ]
		do
			eval "cod=\$(whiptail --default-item "${cod:-0}" --notags --nocancel --menu 'Favoritos' $alt_jan_gr $larg_jan_gr $menu_jan_gr ${i} 3>&2 2>&1 1>&3)"

			if [ "$cod" != "Voltar" ]
			then
				$base/criar_grafico.sh $cod
			fi
		done
	elif [ "$op" == "V" ]
	then
		cod=""
		i=$(sqlite3 -csv -separator " " $db "select id, nome, consultar from locais order by 1" | sed 's/S$/on/;s/N$/off/' | tr '\n' ' ')
		eval "cod=\"\$(whiptail --checklist 'Locais visíveis' $alt_jan_gr $larg_jan_gr $menu_jan_gr ${i} 3>&2 2>&1 1>&3)\""
		
		if [ "$?" -eq 0 ]
		then
			cod="$(echo $cod | sed 's/ /,/g;s/"//g')"
			sql="update locais set consultar = 'N'; update locais set consultar='S' where id in (${cod});"
			sqlite3 $db "$sql"
		fi

		sql="select count(*) from locais where consultar='S';"
		res=$(sqlite3 $db "$sql")
		whiptail --msgbox "Localidades incluídas nas pesquisas: ${res:-0}" $alt_jan_pq $larg_jan_pq
	elif [ "$op" == "P" ]
	then
		cod=""
		i=$(sqlite3 -csv -separator " " $db "select id, item, favorito from vw_obter_lista_produtos;" | sed 's/S$/on/;s/N$/off/' | tr '\n' ' ')
		eval "cod=\"\$(whiptail --checklist 'Produtos favoritos' $alt_jan_gr $larg_jan_gr $menu_jan_gr ${i} 3>&2 2>&1 1>&3)\""

		if [ "$?" -eq 0 ]
		then
			cod="$(echo $cod | sed 's/ /,/g;s/"//g')"
			sql="update produtos set favorito = 'N'; update produtos set favorito='S' where id in (${cod});"
			sqlite3 $db "$sql"
		fi

		sql="select count(*) from produtos where favorito='S';"
		res=$(sqlite3 $db "$sql")
		whiptail --msgbox "Produtos favoritos: ${res:-0}" $alt_jan_pq $larg_jan_pq
	fi
done

tput clear
