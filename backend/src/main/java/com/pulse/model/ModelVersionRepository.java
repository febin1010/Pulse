package com.pulse.model;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface ModelVersionRepository extends JpaRepository<ModelVersion, Long> {
    Optional<ModelVersion> findTopByModelNameAndActiveTrueOrderByCreatedAtDesc(String modelName);
}
