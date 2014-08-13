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

=====

Na primeira execução ele vai iniciar o setup.

O setup vai:

1- verificar se as dependências estão atendidas; 

2- criar o diretório de trabalho pra download temporário das páginas html; 

3- solicitar a inclusão de uma mais categorias pra consulta (pode ser feito novamente no cadastro de categorias); 

4- oferecer a opção pra baixar os dados de produtos e preços do site (pode ser feito mais tarde); 

5- gravar o arquivo de configurações.

Obs.: A base de dados já vem carregada com algumas categorias utilzadas pelo desenvolvedor. Para reiniciá-la vá em "Estatísticas", "Resetar BD".

=====

O script funciona da seguinte forma:

1- Você seleciona uma ou mais categorias para acompanhar os preços;

2- Faz a atualização dos dados diariamente, ou na frequência que preferir. Essa atualização consiste em baixar todas as páginas HTML que aparecem no site sobre aquela categoria. Também é possível colocar o script '_atualizar.sh' na crontab da máquina para automatizar esse processo.

3- Pronto! Agora você consulta os produtos disponíveis nessa categoria de forma prática. Conforme você vai acumulando os dados, de 1 mês, por exemplo, já dá pra ter noção da variação dos preços dos itens que você está interessado em comprar (inclusive é possível marcar um produto como favorito pra facilitar sua busca).

