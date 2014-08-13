boadica
=======

Script em Bash para cache e consultas à função 'Pesquisa de Preços' do site Boa Dica.

=====

Requisitos: dialog 1.2, sqlite 3.6, bash 4.1

Testado no: Fedora 20 (ambiente de testes principal)

Futuramente testado no: Ubuntu 14.04, CentOS 7, Mint 17

=====

Baixe os dados clonando o repositório Git pelo site (download zip) ou com o comando:

$ git clone "https://github.com/diogocalgaro/boadica.git"

Acesse a nova pasta:

$ cd boadica

Inicie com:

$ ./boadica.sh


Na primeira execução ele vai iniciar o setup.
O setup vai:
1- verificar se as dependências estão atendidas; 
2- criar o diretório de trabalho pra download temporário das páginas html; 
3- solicitar a inclusão de uma mais categorias pra consulta (pode ser feito novamente no cadastro de categorias); 
4- oferecer a opção pra baixar os dados de produtos e preços do site (pode ser feito mais tarde); 
5- gravar o arquivo de configurações.

Obs.: A base de dados já vem carregada com algumas categorias utilzadas pelo desenvolvedor.

=====

O script permite consultar as informações de preço da(s) categoria(s) escolhida(s) de forma mais direta e rápida (já que faz cache local dos dados). Além de guardar o histórico da variação dos preços. Para guardar o histórico de forma eficaz, é preciso executar a rotina de carga de dados todos os dias. É possível automatizar esse processo colocando a execução do script "_atualizar.sh" na crontab da máquina.


