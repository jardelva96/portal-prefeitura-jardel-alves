package br.gov.prefeiturajardelalves.portal.security.jwt;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Arrays;
import java.util.Date;

import javax.crypto.SecretKey;

import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

@Component
public class JwtTokenProvider {
    private static final int MIN_HMAC_KEY_BYTES = 32;

    private final JwtProperties properties;

    public JwtTokenProvider(JwtProperties properties) {
        this.properties = properties;
    }

    public String generateToken(Authentication authentication) {
        Instant now = Instant.now();
        Instant expiresAt = now.plus(properties.expiration());

        return Jwts.builder()
                .subject(authentication.getName())
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiresAt))
                .signWith(signingKey())
                .compact();
    }

    public String getUsername(String token) {
        return Jwts.parser()
                .verifyWith(signingKey())
                .build()
                .parseSignedClaims(token)
                .getPayload()
                .getSubject();
    }

    public boolean validateToken(String token) {
        try {
            Jwts.parser()
                    .verifyWith(signingKey())
                    .build()
                    .parseSignedClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException ex) {
            return false;
        }
    }

    private SecretKey signingKey() {
        if (!properties.hasSecret()) {
            throw new IllegalStateException("Configure app.jwt.secret before issuing JWT tokens");
        }

        byte[] key = properties.secret().getBytes(StandardCharsets.UTF_8);
        if (key.length < MIN_HMAC_KEY_BYTES) {
            key = Arrays.copyOf(key, MIN_HMAC_KEY_BYTES);
        }
        return Keys.hmacShaKeyFor(key);
    }
}
