cat > /root/docker-compose.yml <<- "SCRIPT"

version: '3'
services:
  internal-log-fetcher:
    image: gcr.io/o1labs-192920/mina-internal-trace-consumer:1.2.5 # openmina/mina-internal-trace-consumer:2d3bc20
    # image: local/mina-internal-trace-consumer
    container_name: internal-log-fetcher
    restart: always
    command: "fetcher -k /keys/secret_key -o /output --db-uri 'postgresql://postgres:secret_password_12345@postgres:5432' discovery"
    ports:
      - 4000:4000
      - 11000-11700:11000-11700
    volumes:
      - ./keys:/keys
      - ./output:/output
    environment:
      NETWORK: ITN
      INTERNAL_TRACE_CONSUMER_EXE: /internal_trace_consumer
      AWS_ACCESS_KEY_ID: "AKIAZZO2AQDDG27MD7RA"
      AWS_SECRET_ACCESS_KEY: "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"
      AWS_DEFAULT_REGION: us-west-2
      AWS_BUCKET: 673156464838-block-producers-uptime
      AWS_PREFIX: berkeley
    networks:
      - internal-log-fetcher-network

  frontend:
    image: directcuteo/mina-frontend:663f692
    container_name: frontend
    restart: always
    ports:
      - 80:80
    command:
      - sh
      - -ce
      - |
        ENV=$(cat /fe-config.json | tr -d '\n' | tr -s ' ' | sed -e 's/ //g') envsubst < /usr/share/nginx/html/assets/env.template.js > /usr/share/nginx/html/assets/env.js
        exec nginx -g 'daemon off;'
    volumes:
      - ./fe-config.json:/fe-config.json
    networks:
      - internal-log-fetcher-network

  postgres:
    image: postgres
    shm_size: 1g
    container_name: postgres
    restart: always
    ports:
      - 5455:5432
    command: "-c max_connections=10000 -c shared_buffers=2048MB"
    volumes:
      - ./postgresql:/var/lib/postgresql/data
    environment:
      PGDATA: /var/lib/postgresql/data/pgdata
      POSTGRES_PASSWORD: secret_password_12345
    networks:
      - internal-log-fetcher-network
    
networks: #use same network across containers to simplify communication between containers
  internal-log-fetcher-network:
    #driver: bridge
    external: # network created previously by 'docker network create internal-log-fetcher-network' command
      name: internal-log-fetcher-network

SCRIPT
