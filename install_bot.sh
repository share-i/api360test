#!/bin/bash
echo "--- Updating"
sudo apt update
echo "--- Download NVM"
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm" && \. "$NVM_DIR/nvm.sh"
echo "--- Install node.js lts"
nvm install --lts
nvm use --lts
echo "--- Install pm2"
npm install pm2@latest -g
echo "--- Cloning api360test"
cd $HOME
pwd
git clone https://github.com/abugrin/api360test.git
cd api360test
echo "--- Installing Node packages"
npm install
npx next telemetry disable
echo "--- Install and configure nginx"
sudo apt install nginx -y
sudo rm -rf /etc/nginx
sudo mkdir /etc/nginx
sudo mkdir /etc/nginx/ssl
sudo mkdir /etc/nginx/ssl/private
echo "--- Copy certificate files $HOME"
sudo cp $HOME/certificate_full_chain.pem /etc/nginx/ssl
sudo cp $HOME/private_key.pem /etc/nginx/ssl/private
sudo chmod 644 /etc/nginx/ssl/*.pem
sudo chmod 640 /etc/nginx/ssl/private/*.pem
sudo touch /etc/nginx/nginx.conf
echo "--- Writing nginx config to nginx.conf"
echo "
    events {}
    http {
        server {
            listen 443 ssl;
            ssl_certificate         /etc/nginx/ssl/certificate_full_chain.pem;
            ssl_certificate_key     /etc/nginx/ssl/private/private_key.pem;

            location / {
                    proxy_pass http://localhost:3000;
                    proxy_http_version 1.1;
                    proxy_set_header Host \$host;
                    proxy_set_header X-Real-IP \$remote_addr;
                    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                    proxy_set_header Upgrade \$http_upgrade;
                    proxy_set_header Connection "Upgrade";
            }
        }
    }" | sudo tee /etc/nginx/nginx.conf

echo "--- Restart nginx"
sudo systemctl restart nginx
echo "--- Copying .env.local file"
cp $HOME/.env.local $HOME/api360test
cd $HOME/api360test
echo "--- Building app"
npm run build
pm2 start npm --name "api360test" -- start
pm2 save
pm2 startup
NODE=$(nvm version)
USER=${whoami}
sudo env PATH=$PATH:$NVM_BIN $NVM_DIR/versions/node/$NODE/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp $HOME
pm2 restart all