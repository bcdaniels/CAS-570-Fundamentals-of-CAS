"""Unit tests for simpleNeuralModel.py."""
import unittest
import simpleNeuralModel as snm


class TestSimpleNeuralModel(unittest.TestCase):
    
    def test_simple_dynamics_run(self):
        
        Wtest = snm.allToAllNetworkAdjacency(2)
        result = snm.simpleNeuralDynamics(Wtest)
        
        # starting states should be 0 by default
        t0 = 0
        self.assertEqual(result.loc[t0][0], 0.)
        self.assertEqual(result.loc[t0][1], 0.)
        
    def test_simple_dynamics_zero_interactions_zero_noise(self):
        
        Wtest = [[0.,0.],
                 [0.,0.]]
        tFinal = 1.
        result = snm.simpleNeuralDynamics(Wtest,
                                          noiseVar=0.,
                                          tFinal=tFinal)
        
        # ending states should be 0
        self.assertEqual(result.loc[tFinal][0], 0.)
        self.assertEqual(result.loc[tFinal][1], 0.)
