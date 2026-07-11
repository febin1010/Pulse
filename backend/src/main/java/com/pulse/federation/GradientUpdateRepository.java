package com.pulse.federation;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface GradientUpdateRepository extends JpaRepository<GradientUpdate, Long> {
    List<GradientUpdate> findByRoundId(String roundId);
    long countByRoundId(String roundId);
}
