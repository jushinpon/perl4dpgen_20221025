import matplotlib.pyplot as plt
import numpy as np
plt.figure(tight_layout=True, figsize=(8, 8), dpi=150)
f=np.loadtxt("result.f.out")
plt.scatter(f[:,:3].ravel(),  f[:,3:].ravel())
left,right = plt.xlim()
plt.plot(plt.xlim(),plt.xlim(),color='black') 
plt.show()