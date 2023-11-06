# landau.py
#
# Bryan Daniels
# 2022/9/28
#
# Code for computing the bistable "Landau" distribution.
#

import numpy as np

# modified from landauAnalysis.py
def LandauTransitionDistributionRelativeLogPDF(x, mu, cNew, dNew):
    """
    This is a 1D version of the landau distribution
    corresponding to the first principal component.
    
    It uses a different (simpler) parameterization
    than appears in our bee gene expression paper.
    """
    
    term1 = - cNew/2. * (x - mu)**2
    term3 = - (dNew/4.) * (x - mu)**4
    
    return term1 + term3

def LandauDistributionPDF(x, mu, c, d):
    """
    Given a list of equally-spaced x values, approximates a
    normalized density function corresponding to
    LandauTransitionDistributionRelativeLogPDF.
    """
    assert(len(x)>1)
    assert((x[1]-x[0])-(x[-1]-x[-2]) < 1e-6)
    deltax = x[1]-x[0]
    unnormedDist = LandauTransitionDistributionRelativeLogPDF(x, mu, c, d)
    Z = np.sum(np.exp(unnormedDist))
    return 1./Z/deltax*np.exp(unnormedDist)
