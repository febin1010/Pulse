package com.pulse.model;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Map;

@RestController
@RequestMapping("/api/models")
@RequiredArgsConstructor
@Slf4j
public class ModelRegistryController {

    private final ModelVersionRepository repository;

    @Value("${pulse.models.storage-path:/app/models}")
    private String storagePath;

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
        repository.findTopByModelNameAndActiveTrueOrderByCreatedAtDesc(modelVersion.getModelName())
                .ifPresent(old -> {
                    old.setActive(false);
                    repository.save(old);
                });
        modelVersion.setActive(true);
        return ResponseEntity.ok(repository.save(modelVersion));
    }

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<Map<String, Object>> uploadModel(
            @RequestParam("file") MultipartFile file,
            @RequestParam("name") String modelName,
            @RequestParam("version") String version,
            @RequestHeader(value = "X-Base-Url", required = false) String baseUrl) throws IOException {

        // Ensure storage directory exists
        Path storageDir = Paths.get(storagePath);
        Files.createDirectories(storageDir);

        // Save file as {name}-{version}.mlmodel
        String filename = modelName + "-" + version + ".mlmodel";
        Path destination = storageDir.resolve(filename);
        Files.copy(file.getInputStream(), destination, StandardCopyOption.REPLACE_EXISTING);
        log.info("Saved model file: {}", destination);

        // Build download URL
        String downloadUrl = (baseUrl != null ? baseUrl : "https://pulse-production-fccc.up.railway.app")
                + "/api/models/download/" + filename;

        // Deactivate previous version, register new one
        repository.findTopByModelNameAndActiveTrueOrderByCreatedAtDesc(modelName)
                .ifPresent(old -> {
                    old.setActive(false);
                    repository.save(old);
                });

        ModelVersion mv = new ModelVersion();
        mv.setModelName(modelName);
        mv.setVersion(version);
        mv.setDownloadUrl(downloadUrl);
        mv.setActive(true);
        repository.save(mv);

        log.info("Registered model {} v{} at {}", modelName, version, downloadUrl);
        return ResponseEntity.ok(Map.of(
                "modelName", modelName,
                "version", version,
                "downloadUrl", downloadUrl,
                "status", "registered"
        ));
    }

    @GetMapping("/download/{filename}")
    public ResponseEntity<Resource> downloadModel(@PathVariable String filename) throws MalformedURLException {
        Path filePath = Paths.get(storagePath).resolve(filename).normalize();
        Resource resource = new UrlResource(filePath.toUri());

        if (!resource.exists()) {
            return ResponseEntity.notFound().build();
        }

        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .body(resource);
    }
}
