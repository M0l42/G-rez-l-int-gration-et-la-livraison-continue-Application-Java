# ---- Build stage ----
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
# Gradle wrapper and build files first, so dependencies get their own cached layer
COPY gradlew settings.gradle build.gradle .openapi-generator-ignore ./
COPY gradle gradle
RUN ./gradlew dependencies --no-daemon
# Then the sources
COPY src src
RUN ./gradlew bootWar -x test --no-daemon

# ---- Runtime stage ----
FROM eclipse-temurin:21-jre
WORKDIR /app
RUN useradd --system --uid 1001 spring
COPY --from=build /src/build/libs/*.war /app/app.war
USER spring
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.war"]
