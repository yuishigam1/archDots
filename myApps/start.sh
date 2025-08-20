#!/bin/bash
# Start all XAMPP services

echo "Starting all XAMPP services..."
sudo /opt/lampp/xampp start

# Provide feedback to the user
if [ $? -eq 0 ]; then
  echo "All XAMPP services started successfully!"
else
  echo "Failed to start XAMPP services."
fi
