# Use an official lightweight Python runtime as a parent image
FROM python:3.11-slim

# Set the working directory inside the container
WORKDIR /app

# Copy requirements.txt first to exploit Docker layer caching
COPY app/requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the Flask application code
COPY app/app.py .

# Create a system group and non-root system user for security
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -m -s /bin/bash flaskuser

# Grant appropriate permissions to the app directory
RUN chown -R flaskuser:appgroup /app

# Switch to the non-root user
USER flaskuser

# Inform Docker that the container listens on port 5000 at runtime
EXPOSE 5000

# Start the application using Gunicorn (production WSGI server)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
