#arquivo de configuracoes

#opcoes personalizaveis
naveg_opcoes="google-chrome firefox opera konqueror epiphany midori" #ordem de preferencia separados por espacos
view_opcoes="inkview ristretto eog gwenview mate-image-viewer feh mirage viewnior xloadimage gimp inkscape"

#itens fixos - nao alterar
versao="v0.54"
base="$(dirname $0)"
dbname="dados.sqlite3"
db="$base/$dbname"
site="http://www.boadica.com.br"
pag_vendedor="${site}/detalhevendedor.asp?codigo="
url_base="${site}/pesquisa/precos"
dump="dados.dump"
arq_svg="$base/out.svg"

#categoria de produtos do site - configurado pelo script de setup
categ="Jogos PS3"
url_dados="${site}/pesquisa/multi_playstation/precos?ClasseProdutoX=13&CodCategoriaX=13&XT=8&XE=4&XJ=2"
instalado="S"
