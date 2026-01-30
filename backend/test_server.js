const http = require("http");

http.createServer((req, res) => {
    console.log("📡 Request received from phone");
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("PHONE CAN REACH PC");
}).listen(3000, "0.0.0.0", () => {
    console.log("✅ Test server listening on 0.0.0.0:3000");
});
