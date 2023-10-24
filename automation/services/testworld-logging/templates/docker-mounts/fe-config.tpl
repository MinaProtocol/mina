cat > /root/fe-config.json <<- "SCRIPT"
{
	"production": true,
	"aggregator": "/aggregator",
	"isVanilla": true,
	"nodeLister": {
		"domain": "http://localhost",
		"port": 4000
	},
	"globalConfig": {
		"features": {
			"dashboard": ["nodes"],
			"tracing": ["overview", "blocks"]
		}
	},
	"configs": []
}
SCRIPT