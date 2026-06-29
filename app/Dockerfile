# Small, well-supported base image
FROM nginx:1.27-alpine

# Replace the default nginx page with our Hello World page
COPY index.html /usr/share/nginx/html/index.html

# nginx listens on port 80 by default
EXPOSE 80

# Basic container-level healthcheck (the ALB also health-checks "/")
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://localhost:80/ || exit 1

# nginx:alpine already runs nginx in the foreground by default
