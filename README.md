boadica
=======


Script em Bash para cache e consultas a uma categoria do site Boadica.


=====


Baixe os dados clonando o repositório Git pelo site (download zip) ou com o comando:

$ git clone "https://github.com/diogocalgaro/boadica.git"


=====


Requisitos: whiptail 0.52, sqlite 3.6, bash 4.1

Testado no: Fedora 20, Ubuntu 14.04, CentOS 7


=====


A pasta criada pelo git-clone contém, na raiz, a versão de desenvolvimento já configurada e carregada com os dados da categoria "Jogos PS3". Para utilizar uma versão limpa, sem dados nem categoria pré-definida, utilize a cópia da pasta "distrib".

$ cd boadica/distrib

Execute o script com:

$ ./boadica.sh

Na primeira execução ele vai iniciar o setup.
O setup vai:
1- criar uma nova base de dados sqlite3 a partir do dump do último modelo de dados; 
2- carregar as categorias disponíveis no menu "Pesquisa de preços" e perguntar sua escolha (só é possível escolher uma  categoria no momento); 
3- gravar o arquivo "config.inc"; 
4- sugerir a carga inicial dos dados (opcional).


=====


O script permite consultar as informações de preço da categoria escolhida de forma mais direta. Além de guardar o histórico da variação dos preços. Para guardar o histórico é preciso executar a rotina de carga de dados todos os dias. É possível automatizar esse processo colocando a execução do script "obter_dados.sh" na crontab.


