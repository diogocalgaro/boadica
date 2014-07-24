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
		p=$(whiptail --title "Buscar item" --inputbox "Informe as palavras para pesquisa do item" 10 50 3>&2 2>&1 1>&3)
		if [ $? -eq 0 -a -n "$p" ]
		then
			cod=""
			i=$(sqlite3 -csv $db "select id, descricao from vw_buscar_item_ultimo_preco where produto like '%${p}%';" | tr '\n' ' ' | tr ',' ' ')
			i="${i} ' ' ' ' Voltar =============================="

			while [ "$cod" != "Voltar" ]
			do
				eval "cod=\$(whiptail --default-item "${cod:-0}" --nocancel --menu 'Produtos encontrados' 30 130 22 ${i} 3>&2 2>&1 1>&3)"

				if [ "$cod" != "Voltar" ]
				then
					$base/criar_grafico.sh $cod
				fi
			done
		fi
	elif [ "$op" == "I" ]
	then
		p=$(whiptail --title "Consultar itens" --inputbox "Informe o nome da loja" 10 50 3>&2 2>&1 1>&3)
		if [ $? -eq 0 -a -n "$p" ]
		then
			tmp=$(mktemp)
			sqlite3 -cmd ".width 25 35 8 20 12" -header -column $db "select * from vw_buscar_por_loja where Loja like '%${p}%';" > $tmp
			whiptail --title "Consultar itens da loja" --textbox $tmp 60 120
			rm $tmp
		fi
	elif [ "$op" == "C" ]
	then
		echo "Executando rotina de carga dos dados..."
		$base/obter_dados.sh
	elif [ "$op" == "D" ]
	then
		tmp=$(mktemp)
		sqlite3 -header -column $db "select * from vw_diferenca_preco;" > $tmp
		whiptail --title "Diferenças de preço" --textbox $tmp 60 142
		rm $tmp
	elif [ "$op" == "O" ]
	then
		tmp=$(mktemp)
		sqlite3 -cmd ".width 30 45 35 10" -header -column $db "select * from vw_melhores_ofertas;" > $tmp
		whiptail --title "Melhores ofertas" --textbox $tmp 60 142
		rm $tmp
	elif [ "$op" == "N" ]
	then
		tmp=$(mktemp)
		sqlite3 -cmd ".width 30 45 35 10" -header -column $db "select * from vw_novidades;" > $tmp
		whiptail --title "Novidades" --textbox $tmp 50 132
		rm $tmp
	elif [ "$op" == "L" ]
	then
		l=$(whiptail --title "Consultar Loja" --inputbox "Informe o nome da loja" 10 50 3>&2 2>&1 1>&3)
		if [ $? -eq 0 -a -n "$l" ]
		then
			i=$(sqlite3 -csv $db "select id, nome||' ('||localizacao||')' as item from tb_lojas where nome like '%${l}%';" | tr '\n' ' ' | tr ',' ' ')

			eval "cod=\$(whiptail --menu 'Selecione a loja' 30 100 22 ${i} 3>&2 2>&1 1>&3)"
			if [ -n "$cod" ]
			then
				$naveg "${pag_vendedor}${cod}" 2>&1 >/dev/null &
			fi
		fi
	elif [ "$op" == "E" ]
	then
		tmp=$(mktemp)
		sqlite3 -cmd ".width 48" -header -column $db "select * from vw_obter_estatisticas;" > $tmp
		whiptail --title "Estatísticas da base de dados" --textbox $tmp 18 60
		rm $tmp
	elif [ "$op" == "T" ]
	then
		cod=""
		i="Voltar ============================== ' ' ' '"
		j=$(sqlite3 -csv $db "select id, item from vw_obter_lista_produtos;" | tr '\n' ' ' | tr ',' ' ')
		i="${i} ${j} ' ' ' ' Voltar =============================="

		while [ "$cod" != "Voltar" ]
		do
			eval "cod=\$(whiptail --default-item "${cod:-0}" --nocancel --menu 'Todos os produtos' 30 130 22 ${i} 3>&2 2>&1 1>&3)"

			if [ "$cod" != "Voltar" ]
			then
				$base/criar_grafico.sh $cod
			fi
		done
	elif [ "$op" == "F" ]
	then
		cod=""
		i=$(sqlite3 -csv $db "select id, descricao from vw_buscar_favorito_id;" | tr '\n' ' ' | tr ',' ' ')
		i="${i} ' ' ' ' Voltar =============================="

		while [ "$cod" != "Voltar" ]
		do
			eval "cod=\$(whiptail --default-item "${cod:-0}" --nocancel --menu 'Favoritos' 50 140 42 ${i} 3>&2 2>&1 1>&3)"

			if [ "$cod" != "Voltar" ]
			then
				$base/criar_grafico.sh $cod
			fi
		done
	elif [ "$op" == "V" ]
	then
		cod=""
		i=$(sqlite3 -csv -separator " " $db "select id, nome, consultar from locais order by 1" | sed 's/S$/on/;s/N$/off/' | tr '\n' ' ')
		eval "cod=\"\$(whiptail --checklist 'Locais visíveis' 22 80 14 ${i} 3>&2 2>&1 1>&3)\""
		
		if [ "$?" -eq 0 ]
		then
			cod="$(echo $cod | sed 's/ /,/g;s/"//g')"
			sql="update locais set consultar = 'N'; update locais set consultar='S' where id in (${cod});"
			sqlite3 $db "$sql"
		fi

		sql="select count(*) from locais where consultar='S';"
		res=$(sqlite3 $db "$sql")
		whiptail --msgbox "Localidades incluídas nas pesquisas: ${res:-0}" 7 50
	elif [ "$op" == "P" ]
	then
		cod=""
		i=$(sqlite3 -csv -separator " " $db "select id, item, favorito from vw_obter_lista_produtos;" | sed 's/S$/on/;s/N$/off/' | tr '\n' ' ')
		eval "cod=\"\$(whiptail --checklist 'Produtos favoritos' 40 100 32 ${i} 3>&2 2>&1 1>&3)\""

		if [ "$?" -eq 0 ]
		then
			cod="$(echo $cod | sed 's/ /,/g;s/"//g')"
			sql="update produtos set favorito = 'N'; update produtos set favorito='S' where id in (${cod});"
			sqlite3 $db "$sql"
		fi

		sql="select count(*) from produtos where favorito='S';"
		res=$(sqlite3 $db "$sql")
		whiptail --msgbox "Produtos favoritos: ${res:-0}" 7 50
	fi
done

tput clear
