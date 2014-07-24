#!/bin/bash
################################################################################
#
# Script de consulta aos dados de uma categoria específica do site BoaDica
#
# github.com/diogocalgaro/boadica
#
################################################################################

#verificando a instalacao
$(dirname $0)/setup.sh x #se o script receber algum parametro ele sabe que foi chamado por outro script
if [ ! $? -eq 0 ]
then
	exit $?
fi


#config basica
source $(dirname $0)/config.inc


#variaveis
op="B"


#configuracoes de tamanho da janela
eval "$(resize|head -n2|sed 's/^/export /g'|tr -d '\n')"

if [ ${COLUMNS:-30} -le 30 -o ${LINES:-12} -le 12 ]
then
	echo "O terminal não atende ao tamanho mínimo de 30x12."
	exit 1
fi

larg_jan_gr=$(( COLUMNS -6 )) #janelas grandes que ocupam toda a tela
alt_jan_gr=$(( LINES -6 ))
col_jan_gr=$(( larg_jan_gr -12 )) #largura da coluna descricao em janelas grandes
menu_jan_gr=$(( alt_jan_gr -8 )) #altura util do menu em janelas grandes

if [ ${larg_jan_gr:-0} -lt 50 ]
then
	larg_jan_pq=${larg_jan_gr:-0} #janelas pequenas centralizadas
else
	larg_jan_pq=50
fi
if [ ${alt_jan_gr:-0} -lt 10 ]
then
	alt_jan_pq=${alt_jan_gr:-0}
else
	alt_jan_pq=10
fi
menu_jan_pq=$(( alt_jan_pq -8 )) #altura util do menu em janelas pequenas

if [ ${larg_jan_gr:-0} -lt 70 ]
then
	larg_jan_md=${larg_jan_gr:-0} #janelas pequenas centralizadas
else
	larg_jan_md=70
fi
if [ ${alt_jan_gr:-0} -lt 25 ]
then
	alt_jan_md=${alt_jan_gr:-0}
else
	alt_jan_md=25
fi
menu_jan_md=$(( alt_jan_md -8 )) #altura util do menu em janelas pequenas


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
			i=$(sqlite3 -csv $db "select id, substr(descricao,1,$col_jan_gr) from vw_buscar_item_ultimo_preco where produto like '%${p}%';" | tr '\n' ' ' | tr ',' ' ')
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
				$naveg_cmd "${pag_vendedor}${cod}" 2>&1 >/dev/null &
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
