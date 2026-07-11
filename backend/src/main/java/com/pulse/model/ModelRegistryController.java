package com.pulse.model;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/models")
@RequiredArgsConstructor
public class ModelRegistryController {

    private final ModelVersionRepository repository;

    @GetMapping("/latest")
    public ResponseEntity<Map<String, Object>> getLatest(@RequestParam String name) {
        return repository.findTopByModelNameAndActiveTrueOrderByCreatedAtDesc(name)
                .map(mv -> {
                    Map<String, Object> body = Map.of(
                            "modelName", mv.getModelName(),
                            "version", mv.getVersion(),
                            "downloadUrl", mv.getDownloadUrl(),
                            "createdAt", mv.getCreatedAt().toString()
                    );
                    return ResponseEntity.<Map<String, Object>>ok(body);
                })
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping("/register")
    public ResponseEntity<ModelVersion> register(@RequestBody ModelVersion modelVersion) {
        // Deactivate previous versions of same model
        repository.findTopByModelNameAndActiveTrueOrderByCreatedAtDesc(modelVersion.getModelName())
                .ifPresent(old -> {
                    old.setActive(false);
                    repository.save(old);
                });
        modelVersion.setActive(true);
        return ResponseEntity.ok(repository.save(modelVersion));
    }
}
