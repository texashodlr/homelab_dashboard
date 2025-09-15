mkdir prometheus && cd prometheus

sleep 1

wget https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz

sleep 1

tar xvfz node_exporter-1.9.1-amd64.tar.gz

sleep 1

cd node_exporter-1.9.1-amd64/

sleep 1

./node_exporter
