package br.gov.prefeiturajardelalves.portal.security.jwt;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.jwt")
public record JwtProperties(
        String secret,
        long expirationMs,
        long refreshExpirationMs
) {
    public Duration expiration() {
        return Duration.ofMillis(expirationMs);
    }

    public Duration refreshExpiration() {
        return Duration.ofMillis(refreshExpirationMs);
    }

    public boolean hasSecret() {
        return secret != null && !secret.isBlank();
    }
}
