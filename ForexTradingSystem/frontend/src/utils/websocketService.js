class WebSocketService {
  constructor(url) {
    this.url = url;
    this.socket = null;
    this.callbacks = {};
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
    this.reconnectInterval = 5000;
  }

  connect() {
    this.socket = new WebSocket(this.url);

    this.socket.onopen = () => {
      this.reconnectAttempts = 0;
      console.log('WebSocket connected');
    };

    this.socket.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (this.callbacks[message.type]) {
        this.callbacks[message.type](message.data);
      }
    };

    this.socket.onclose = () => {
      console.log('WebSocket disconnected');
      if (this.reconnectAttempts < this.maxReconnectAttempts) {
        setTimeout(() => {
          this.reconnectAttempts++;
          this.connect();
        }, this.reconnectInterval);
      }
    };

    this.socket.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
  }

  subscribe(eventType, callback) {
    this.callbacks[eventType] = callback;
  }

  unsubscribe(eventType) {
    delete this.callbacks[eventType];
  }

  send(message) {
    if (this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(JSON.stringify(message));
    }
  }

  disconnect() {
    if (this.socket) {
      this.socket.close();
    }
  }
}

const wsService = new WebSocketService('ws://localhost:5000/ws');
export default wsService;
