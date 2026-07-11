package com.pulse.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "model_versions")
@Data
@NoArgsConstructor
public class ModelVersion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String modelName;

    @Column(nullable = false)
    private String version;

    @Column(nullable = false)
    private String downloadUrl;

    private boolean active;

    private LocalDateTime createdAt = LocalDateTime.now();
}
