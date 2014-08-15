#arquivo de configuracoes

#opcoes personalizaveis
#ordem de preferencia para os aplicativos de navegador, visualizador de imagens e downloader
#itens separados por espaco
naveg_opcoes="google-chrome firefox opera konqueror epiphany midori"
view_opcoes="inkview ristretto eog mate-image-viewer feh xloadimage gimp inkscape xdg-open"
dw_opcoes="curl aria2c wget"

#itens fixos - nao alterar
versao="v0.71"
site="http://www.boadica.com.br"
pag_vendedor="${site}/detalhevendedor.asp?codigo="
url_base="${site}/pesquisa/precos"
base="$(dirname $0)"
dbname="dados.sqlite3"
db="$base/$dbname"
arq_svg="$base/_grafico.svg"
workdir="$base/workdir"
sql_limit="limit 500"
max_pags=200
instalado="N"
