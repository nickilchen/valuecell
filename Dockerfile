FROM ubuntu:25.10
WORKDIR /app

# Copy the application into the container.
COPY . /app

RUN apt-get update && \
    apt-get install curl

# Install the application dependencies.
RUN bash start.sh

EXPOSE 8000

# Run the application.
CMD ["uv", "run", "python", "main.py", "--host", "0.0.0.0", "--port", "8000"]
