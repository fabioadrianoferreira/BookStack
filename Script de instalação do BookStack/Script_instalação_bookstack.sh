#script escrito por Fabio Adriano Ferreira Terleski
#*************


#!/bin/bash

echo "*********************************************************************************"
echo "               Script para instalar o BookStack no Debian 13                     "
echo "*********************************************************************************"

echo "================================================================================="
echo "                   Instalando o Git, Unzip, Curl e Vim                           "
echo "================================================================================="
# Atualiza a lista de pacotes
apt update -y

# Instala os pacotes necessários
if apt install -y gnupg git unzip curl vim; then
    echo "Instalação dos programas git, unzip, curl e vim realizada com sucesso."
else
    echo "Ocorreu um erro durante a instalação dos programas git, unzip, curl e vim."
    exit 1
fi

echo "================================================================================="
echo "                             Instalando Nginx                                    "
echo "================================================================================="

# Instala o Nginx
echo "Instalando o Nginx..."
if apt install -y nginx; then
    echo "Instalação do Nginx realizada com sucesso."
else
    echo "Ocorreu um erro durante a instalação do Nginx."
    exit 1
fi

# Iniciando o Nginx
echo "Adicionando o Nginx à inicialização do sistema."
systemctl enable nginx

echo "Startando o Nginx."
systemctl start nginx

# Validando se o Nginx está com o estado active
echo "Validando estado do Nginx..."
NGINX_STATUS=$(systemctl is-active nginx)

if [ "$NGINX_STATUS" = "active" ]; then
    echo "Boaaaa =) !! O Nginx já está instalado, ativo e em execução. Bora prosseguir!"
else
    echo "Ixiii Deu ruimm =( !! O Nginx não iniciou corretamente."
    echo "Status atual: $NGINX_STATUS"
    exit 1
fi

echo "================================================================================="
echo "                           Instalando o MariaDB                                  "
echo "================================================================================="

# Instala o MariaDB 
echo "Instalando o MariaDB Server e Client..."
if apt install -y mariadb-server mariadb-client; then
    echo "Boaaaa =) !! O MariaDB Server e Client foram instalados corretamente."
else
    echo "Ixiii Deu ruimm =( !! O MariaDB Server e Client não foram instalados corretamente."
    exit 1
fi

# Iniciando o MariaDB
echo "Adicionando o MariaDB à inicialização do Sistema Operacional"
systemctl enable mariadb

echo "Iniciando o MariaDB"
systemctl start mariadb

echo "Validando estado do MariaDB..."
MARIADB_STATUS=$(systemctl is-active mariadb)

if [ "$MARIADB_STATUS" = "active" ]; then
    echo "Boaaaa =) !! O MariaDB já está ativo e em execução. Bora prosseguir!"
else
    echo "Ixiii Deu ruimm =( !! O MariaDB não iniciou corretamente."
    echo "Status atual: $MARIADB_STATUS"
    exit 1
fi

echo "================================================================================="
echo "                        Configuração inicial do MariaDB                          "
echo "================================================================================="

# Pede a senha que será usada para o root
echo "*********************************************************************************"
echo "Importante!! Digite a senha para o usuário ROOT do MariaDB"
read -s -p "Importante, guarde essa senha com segurança: " ROOT_PASS
echo ""

# Executa os comandos no MariaDB
mariadb -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host!='localhost';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF

# Verifica se deu certo
if [ $? -eq 0 ]; then
    echo "Boaaaa =) !! A configuração inicial do MariaDB foi realizada com sucesso!"
else
    echo "Ixiii Deu ruimm =( !! Ocorreu um erro durante a configuração do MariaDB."
    exit 1
fi

echo "================================================================================="
echo "                    Adicionando o repositório do PHP                             "
echo "================================================================================="

# Adicionando o repositório do PHP
curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
dpkg -i /tmp/debsuryorg-archive-keyring.deb
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
apt update -y
echo "Boaaaa =) !! O repositório foi adicionado com sucesso. Bora prosseguir!"

echo "================================================================================="
echo "                      Instalando os pacotes do PHP                               "
echo "================================================================================="

# Instalando os pacotes do PHP
if apt install -y php8.3 php8.3-fpm php8.3-mbstring php8.3-curl php8.3-xml php8.3-zip php8.3-gd php8.3-ldap php8.3-mysql php8.3-intl; then
    echo "Boaaaa =) !! A instalação dos pacotes foi realizada com sucesso."
else
    echo "Ixiii Deu ruimm =( !! Ocorreu um erro na instalação dos pacotes do PHP."
    exit 1
fi

# Startando o php8.3-fpm
echo "Adicionando o php8.3-fpm à inicialização do sistema"
systemctl enable php8.3-fpm

echo "Startando o php8.3-fpm"
systemctl start php8.3-fpm

# Validando se o PHP8.3 está ativo
echo "Validando estado do php8.3-fpm..."
PHP83_STATUS=$(systemctl is-active php8.3-fpm.service)
if [ "$PHP83_STATUS" = "active" ]; then
    echo "Boaaaa =) !! O php8.3-fpm está ativo e em execução. Bora prosseguir!"
else
    echo "Ixiii Deu ruimm =( !! O php8.3-fpm não está ativo." 
    echo "Status atual: $PHP83_STATUS"
    exit 1
fi

echo "================================================================================="
echo "                Criando o banco de dados bookstack no MariaDB                    "
echo "================================================================================="

echo "*********************************************************************************"
echo "O script agora irá criar o banco 'bookstack' e o usuário 'bookstack'."
read -s -p "Importante!! Digite uma senha para o usuário 'bookstack' do MariaDB: " BOOKSTACK_PASS
echo ""
echo "*********************************************************************************"
read -s -p "Digite novamente a senha do ROOT do MariaDB: " ROOT_PASS
echo ""

# Criando banco e usuário
mariadb -u root -p"${ROOT_PASS}" <<EOF
CREATE DATABASE bookstack;
CREATE USER 'bookstack'@'localhost' IDENTIFIED BY '${BOOKSTACK_PASS}';
GRANT ALL PRIVILEGES ON bookstack.* TO 'bookstack'@'localhost';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo "Boaaaa =) !! Banco e usuário 'bookstack' criados com sucesso!"
else
    echo "Ixiii Deu ruimm =( !! Ocorreu um erro ao criar o banco ou o usuário no MariaDB."
    exit 1
fi

echo "================================================================================="
echo "                        Instalando o Composer (PHP)                              "
echo "================================================================================="

echo "Baixando instalador do Composer..."
if php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"; then
    echo "Instalador baixado com sucesso."
else
    echo "Falha ao baixar o instalador do Composer."
    exit 1
fi

echo "Iniciando a instalação..."
if php composer-setup.php; then
    echo "Boaaaa =) !! Composer instalado. Bora prosseguir!"
else
    echo "Ixiii Deu ruimm =( !! Falha ao executar o instalador do Composer."
    rm -f composer-setup.php
    exit 1
fi

echo "Removendo arquivo de instalação..."
php -r "unlink('composer-setup.php');"

echo "Movendo o composer para /usr/local/bin..."
if mv composer.phar /usr/local/bin/composer; then
    chmod +x /usr/local/bin/composer
    echo "*****************************************************************************"
    echo "Boaaaa =) !! Composer movido e pronto para uso."
    echo "Agora aperte a tecla ENTER e depois digite yes"
else
    echo "Ixiii Deu ruimm =( !!Falha ao mover o composer.phar para /usr/local/bin/"
    exit 1
fi

if composer --version > /dev/null 2>&1; then
    echo "Boaaaa =) !! Instalação concluída com sucesso!"
    composer --version
else
    echo "Ixiii Deu ruimm =( !! Composer não está funcionando corretamente."
    exit 1
fi

echo "================================================================================="
echo "                     Clonando e instalando o BookStack                           "
echo "================================================================================="

cd /var/www || { echo "Falha ao acessar /var/www"; exit 1; }

echo "Clonando o repositório do BookStack (branch release)..."
if git clone https://github.com/BookStackApp/BookStack.git --branch release --single-branch bookstack; then
    
    echo "*****************************************************************************"
    echo "Boaaaa =) !! Repositório BookStack clonado com sucesso."
    echo "Agora digite novamente yes"
else
    echo "Ixiii Deu ruimm =( !! Falha ao clonar o repositório BookStack."
    exit 1
fi

cd /var/www/bookstack || exit 1
composer install --no-dev

echo "================================================================================="
echo "                     Copiando e editando o arquivo .env                          "
echo "================================================================================="

cp .env.example .env

sed -i '/^APP_URL=https:\/\/example\.com$/d' .env
sed -i '/^DB_HOST=localhost$/d' .env
sed -i '/^DB_DATABASE=database_database$/d' .env
sed -i '/^DB_USERNAME=database_username$/d' .env
sed -i '/^DB_PASSWORD=database_user_password$/d' .env

read -p "Digite a URL que será usada para o serviço do BookStack (ex: https://example.org): " URL

if [ -z "$URL" ] || [[ ! "$URL" =~ ^https?:// ]]; then
    echo "Ixiii Deu ruimm =( !! URL inválida!"
    exit 1
fi

cat >> .env <<EOF
APP_URL=${URL}
DB_HOST=127.0.0.1
DB_DATABASE=bookstack
DB_USERNAME=bookstack
DB_PASSWORD=${BOOKSTACK_PASS}
EOF

echo "================================================================================="
echo "                      Alterando os donos dos diretórios                          "
echo "================================================================================="

chown -R www-data:www-data /var/www/bookstack/storage /var/www/bookstack/bootstrap/cache /var/www/bookstack/public/uploads

echo "================================================================================="
echo "                        Gerando a chave no arquivo .env                          "
echo "================================================================================="
echo "*********************************************************************************"
echo " Mude a opção para yes"
echo "*********************************************************************************"
php artisan key:generate

echo "================================================================================="
echo "                   Atualizando o banco bookstack no MariaDB                      "
echo "================================================================================="
echo "*********************************************************************************"
echo " Mude a opção para yes"
echo "*********************************************************************************"
php artisan migrate

echo "================================================================================="
echo "                  Criando arquivo virtual host para o Nginx                      "
echo "================================================================================="

VHOST_FILE="/etc/nginx/sites-available/bookstack.conf"
DOMAIN="${URL#http://}"
DOMAIN="${DOMAIN#https://}" 

if [[ "$URL" == https* ]]; then
    cat > "$VHOST_FILE" <<EOF
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/bookstack/public;
    index index.php;

    ssl_certificate ;
    ssl_certificate_key ;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    access_log /var/log/nginx/bookstack.access.log;
    error_log /var/log/nginx/bookstack.error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_index index.php;
    }

    location ~ /\.ht {
        deny all;
    }
}

server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$host\$request_uri;
}
EOF

    read -p "Digite o caminho do arquivo .crt: " CRT
    read -p "Agora digite o caminho do arquivo .key: " KEY

    sed -i "s|^ *ssl_certificate .*|ssl_certificate $CRT;|" "$VHOST_FILE"
    sed -i "s|^ *ssl_certificate_key .*|ssl_certificate_key $KEY;|" "$VHOST_FILE"
else
    cat > "$VHOST_FILE" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/bookstack/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_index index.php;
    }

    client_max_body_size 12M;
    access_log /var/log/nginx/bookstack-access.log;
    error_log /var/log/nginx/bookstack-error.log;
}
EOF
fi

echo "================================================================================="
echo "               Excluindo arquivo default e seu link simbólico                    "
echo "================================================================================="

rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

echo "================================================================================="
echo "                         Criando novo link simbólico                             "
echo "================================================================================="

ln -s /etc/nginx/sites-available/bookstack.conf /etc/nginx/sites-enabled/

echo "================================================================================="
echo "      Validando se existe algum erro no vhost e reiniciando os serviços          "
echo "================================================================================="

if nginx -t; then
    echo "Boaaaa =) !! Arquivo de configuração Nginx está OK!"
else
    echo "Ixiii Deu ruimm =( !! Erro na configuração do Nginx."
    exit 1
fi

systemctl restart mariadb php8.3-fpm nginx

echo "Validando estado dos serviços..."
for svc in nginx mariadb php8.3-fpm; do
    STATUS=$(systemctl is-active "$svc")
    if [ "$STATUS" = "active" ]; then
        echo "Boaaaa =) !! O serviço $svc está ativo e em execução."
    else
        echo "Ixiii Deu ruimm =( !! O serviço $svc não está ativo. Status: $STATUS"
        exit 1
    fi
done

echo "================================================================================="
echo "                      Script concluído com sucesso                               "
echo "================================================================================="

echo "Caro leitor, se você chegou até aqui, muito provável que a sua instalação do" 
echo "BookStack tenha sido executada com sucesso."
echo "Agora, abra uma aba do navegador e digite a URL que você usou no passo anterior."
echo ""
echo ""
echo "Ah, quase esquecendo!"
echo "A senha e o usuário padrão do BookStack são:"
echo "Seu domínio é: $URL - Caso você não tenha um servidor DNS, adicione a URL"
echo "no /etc/hosts da máquina que for acessar via navegador web"
echo "Usuário (e-mail): admin@admin.com"
echo "Senha: password"
echo "Após logar mude as credenciais "
echo""
echo""
echo "Saúde e Liberdade!"
echo "\"O conhecimento, quando não humaniza, deprava.\""

