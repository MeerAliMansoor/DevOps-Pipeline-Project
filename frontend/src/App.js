import React, { useEffect, useState } from "react";

function App() {
  const [message, setMessage] = useState("Connecting...");

  useEffect(() => {
    fetch(`${process.env.REACT_APP_BACKEND_URL}`)
      .then((res) => res.text())
      .then((data) => setMessage(data))
      .catch((err) => setMessage("Error connecting to backend"));
  }, []);

  return (
    <div>
      <h1>Frontend + Backend Connection</h1>
      <p>{message}</p>
    </div>
  );
}

export default App;

