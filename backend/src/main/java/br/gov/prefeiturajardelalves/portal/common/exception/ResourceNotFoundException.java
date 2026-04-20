package br.gov.prefeiturajardelalves.portal.common.exception;

public class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String message) {
        super(message);
    }

    public ResourceNotFoundException(String resource, Object id) {
        super("%s nao encontrado: %s".formatted(resource, id));
    }
}
