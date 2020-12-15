#! /bin/bash

cat << EOF > /etc/nginx/conf.d/default.conf
server_names_hash_bucket_size 64;
server {
  root /opt/aptly/public;
  server_name ${HOSTNAME};

  location / {
    autoindex on;
  }
  
  # This is the access to the aptly api
  # used for pushing new files and publishing
  location /api/ {
    client_max_body_size 100M;
    proxy_pass http://localhost:8080/api/;
  }
}
EOF
