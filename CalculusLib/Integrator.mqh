// CIntegrator.mqh - The Core Consciousness Engine
#property strict

struct NodeData {
    double  AwarenessScore; // Cumulative Input
    double  Jerk;           // Change in Acceleration
    double  Snap;           // Change in Jerk
    bool    IsActive;
};

class CIntegrator {
private:
    double m_total_consciousness;
    NodeData m_buffer[27]; // The Array

public:
    CIntegrator() : m_total_consciousness(0.0) {
        ArrayInitialize(m_buffer, 0.0);
    }

    // Accumulates Awareness into the Integral
    void Integrate(double input_awareness, int node_id) {
        if(node_id < 0 || node_id >= 27) return;
        
        m_buffer[node_id].AwarenessScore += input_awareness;
        m_total_consciousness += input_awareness;
    }

    // The Filter: Ensure Positive Snap/Jerk
    bool IsSignalViable(int node_id) {
        // Only engage if Snap is positive (Acceleration is increasing)
        return (m_buffer[node_id].Snap > 0);
    }
    
    double GetTotalConsciousness() { return m_total_consciousness; }
};