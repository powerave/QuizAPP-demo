FROM dart:stable

WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN dart pub get
COPY bin ./bin

ENV PORT=8080
ENV REDIS_HOST=redis
ENV REDIS_PORT=6379
ENV POSTGRES_HOST=postgres
ENV POSTGRES_PORT=5432
ENV POSTGRES_DB=quizapp
ENV POSTGRES_USER=quizapp
ENV POSTGRES_PASSWORD=quizapp
EXPOSE 8080

CMD ["dart", "run", "bin/server.dart"]
