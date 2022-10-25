import matplotlib.pyplot as plt
import numpy as np
plt.figure(tight_layout=True, figsize=(8, 8), dpi=150)
f=np.loadtxt("./temp1.e.out")
#print("shape of data:",f.shape)

#print("datatype of data:",f.dtype)
#print (f[:5,0:])
#print (f[0,1])
plt.scatter(f[:,:1].ravel(),  f[:,1:].ravel())
#left,right = plt.xlim()
#print (left,right)
plt.xlabel('Ref. Energy (eV)')
plt.ylabel('Pred. Energy (eV)')
plt.grid()
plt.plot(plt.xlim(),plt.xlim(),color='black')
#plt.plot(f['Day'], f['improvement'], label='Improvement',marker='o',markevery= 20, linewidth=1.5, markersize=10)
#plt.savefig("energy.png") 
plt.show()