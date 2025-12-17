FROM nginx:alpine
RUN echo "<h1>Hola! Mi build de Google Cloud funciono</h1>" > /usr/share/nginx/html/index.html
