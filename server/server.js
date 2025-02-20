const WebSocket = require("ws");
const wss = new WebSocket.Server({ port: 8000 });

let channels = {};

wss.on("connection", (ws) => {
  ws.on("message", (message) => {
    let data = JSON.parse(message);
    let channel = data.channel;

    if (!channels[channel]) channels[channel] = [];
    channels[channel].push(ws);

    channels[channel].forEach((client) => {
      if (client !== ws && client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify(data));
      }
    });
  });

  ws.on("close", () => {
    for (let channel in channels) {
      channels[channel] = channels[channel].filter((client) => client !== ws);
      if (channels[channel].length === 0) delete channels[channel];
    }
  });
});

console.log("WebSocket signaling server running on ws://localhost:8000");

