FROM nginx:alpine
# Esto copia TODOS tus archivos (incluyendo Resonance.html) al servidor
COPY . /usr/share/nginx/html/
