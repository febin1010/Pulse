package com.pulse.federation;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.Map;

@Entity
@Table(name = "gradient_updates")
@Data
@NoArgsConstructor
public class GradientUpdate {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String deviceId;

    // category -> delta value (e.g. "food" -> +0.12)
    @ElementCollection
    @CollectionTable(name = "gradient_deltas", joinColumns = @JoinColumn(name = "update_id"))
    @MapKeyColumn(name = "category")
    @Column(name = "delta")
    private Map<String, Double> categoryDeltas;

    private String roundId;

    private LocalDateTime receivedAt = LocalDateTime.now();
}
