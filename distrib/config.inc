#arquivo de configuracoes

#opcoes personalizaveis
naveg="google-chrome"
view_opcoes="inkview ristretto eog gwenview mate-image-viewer feh mirage viewnior xloadimage gimp inkscape xdg-open"

#itens fixos - nao alterar
versao="v0.50"
base="$(dirname $0)"
dbname="dados.sqlite3"
db="$base/$dbname"
site="http://www.boadica.com.br"
pag_vendedor="${site}/detalhevendedor.asp?codigo="
url_base="${site}/pesquisa/precos"
dump="dados.dump"
arq_svg="$base/out.svg"

#categoria de produtos do site - configurado pelo script de setup
categ=""
url_dados=""
instalado="N"
