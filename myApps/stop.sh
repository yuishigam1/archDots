#!/bin/bash
# Stop all XAMPP services

echo "Stopping all XAMPP services..."
sudo /opt/lampp/xampp stop

# Provide feedback to the user
if [ $? -eq 0 ]; then
  echo "All XAMPP services stopped successfully!"
else
  echo "Failed to stop XAMPP services."
fi
