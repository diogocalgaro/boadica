#arquivo de configuracoes

#opcoes personalizaveis - ordem de preferencia, itens separados por espaco
naveg_opcoes="google-chrome firefox opera konqueror epiphany midori"
view_opcoes="inkview ristretto eog gwenview mate-image-viewer feh mirage viewnior xloadimage gimp inkscape"
dw_opcoes="curl aria2c wget"

#itens fixos - nao alterar
versao="v0.70"
site="http://www.boadica.com.br"
pag_vendedor="${site}/detalhevendedor.asp?codigo="
url_base="${site}/pesquisa/precos"
base="$(dirname $0)"
dbname="dados.sqlite3"
db="$base/$dbname"
dump="$base/dados.dump"
arq_svg="$base/out.svg"
workdir="$base/workdir"
instalado="S"
