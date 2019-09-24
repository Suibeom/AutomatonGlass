using Images
using Base.Iterators
using Distributed
using SharedArrays
function rule73(a,b,c)
  if (a & b & !c) | (!a & b & c) | (!a & !b & !c)
    return true
  else
    return false
  end
end



function lotterysample(b)
       k = sum(values(b))
       n = rand()*k
       a = copy(b)
       while(n >= a[argmin(a)])
       a[argmin(a)] += k
       end
       return argmin(a)
end

function mcselect(A, l, vals,center,T)
  B=copy(A)
  C=Dict()
  for v in vals
    for i in 1:length(l)
      B[(center.+l[i])...]= v[i]
    end
    C[v] = δ(B,A)^T
  end
  v = lotterysample(C)
  for i in 1:length(l)
    global A[(center.+l[i])...]= v[i] #Dangerous... Hopefully worth it.
  end
  return C
end


function delta(a,b,c,d,r)
  return r(a,b,c) == d ? 0 : 1
end
function H(A,r)
  sum([delta(A[i,j-1],A[i,j],A[i,j+1],A[i+1,j],r) for j in 2:size(A)[2]-1, i in 1:size(A)[1]-1])
end

function regions(A,r)
 return [delta(A[i,j-1],A[i,j],A[i,j+1],A[i+1,j],r)==1 for j in 2:size(A)[2]-1, i in 1:size(A)[1]-1]
end

function δ(A,B)
  return exp(H(B,r)-H(A,r))
end

function simol(l,m,n,s,T,β)
       A = rand(Bool, (n,n))
       for j in 1:l
       d = 0
       for i in 1:m
       B = [rand() < β*(i/m) for i in 1:n, j in 1:n]
       #print(i," ", δ(A, A.⊻B),"\n")
       if rand() < T*δ(A.⊻B,A)
       A = A.⊻B
       #print("Ping!\n")
       d=d+1
       end
       end
       print(d/m,"\n")
       print(H(A,rule73),"\n")

       save(s*string(j)*".jpg", colorview(Gray, A))
       end
end


function HBath(o,m,n,s,T)
              A = rand(Bool, (n,n))
              k,l = rand(1:n),rand(1:n)
              for j in 1:o
              d = 0
              for i in 1:m
              C=[A[i,j] for i in max(1,k-2):min(k+2,n), j in max(1,l-2):min(l+2,n)]
              D=[(i,j)==(k,l) ? !A[i,j] : A[i,j] for i in max(1,k-2):min(k+2,n), j in max(1,l-2):min(l+2,n)]


              #print(i," ", δ(A, A.⊻B),"\n")
              if rand() < δ(D,C)^T
              A[k,l] = !A[k,l]
              d=d+1
              end
              k,l = rand(1:n),rand(1:n)
              end
              write(stdout, "Accept rate:"*string(d/m)*"\n") #Step accept rate
              write(stdout, "Step (out of"*string(o)*"):"* string(j)*"\n")
              write(stdout, string(H(A,rule73))*"\033[F\033[F") #Current entropy.
              save(s*lpad(string(j),10,string(0))*".png", colorview(Gray, A))
              end
              write(stdout,"\n")
end
#Current problem; How do I  parallelize this?
function annealsched(t)
	return 0.5*(1-cos(t*pi))
end
function HBathAnneal(o,m,n,s,Tl,Th,w,p)
              A = rand(Bool, (n,n))
              k,l = rand(1:n),rand(1:n)
              for j in 1:o
              d = 0
              for i in 1:m
              C=[A[i,j] for i in max(1,k-2):min(k+2,n), j in max(1,l-2):min(l+2,n)]
              D=[(i,j)==(k,l) ? !A[i,j] : A[i,j] for i in max(1,k-2):min(k+2,n), j in max(1,l-2):min(l+2,n)]


              #print(i," ", δ(A, A.⊻B),"\n")
              if rand() < δ(D,C)^((Tl-Th)*annealsched(w*((i + j*m)%p)/p+Th))
              A[k,l] = !A[k,l]
              d=d+1
              end
              k,l = rand(1:n),rand(1:n)
              end
              write(stdout, "Accept rate:"*string(d/m)*"\n") #Step accept rate
              write(stdout, "Step (out of"*string(o)*"):"* string(j)*"\n")
              write(stdout, string(H(A,r))*"\033[F\033[F") #Current entropy.
              save(s*lpad(string(j),10,string(0))*".png", colorview(Gray, A))
              save("r"*s*lpad(string(j),10,string(0))*".png", colorview(Gray, regions(A,r)))
              end
              write(stdout,"\n")
end

function HBathf(o,m,n,s,T)
              A = []
              for i in 1:9
                A = [A..., [true, false]]
              end
              vals = product(A...)
              #pts = [(0,0),(0,1),(0,-1),(1,0)]
              pts = [(a,b) for a in -1:1, b in -1:1]
              A = rand(Bool, (n,n))

              for j in 1:o
              d = 0
              for c in 1:m          
              k,l = rand(2:n-1),rand(2:n-1)

              C=[A[i,j] for i in max(1,k-2):min(k+2,n), j in max(1,l-2):min(l+2,n)]
              center = (3 + min(k-3,0), 3 + min(l-3,0))
              D = copy(C)
              mcselect(C, pts,vals,center, T)
              #We want propose replacements for this four-point configuration.

              #There are 2^4 different configurations we can replace it with,
              #and we should propose our options randomly inversely proportionately to their cost.
              #We have to do this because it has to be possible to propose bad moves!

              write(stdout, "Accept rate:"*string(d/c)*"\n") #Step accept rate
              if rand() < δ(D,C)^T
              for p in pts
                  A[(p.+(k,l))...]= C[(center.+p)...]
              end
              d=d+1
              #print(d,"\r")
              end
              end
              write(stdout, "Accept rate:"*string(d/m)*"\n") #Step accept rate
              write(stdout, "Step (out of"*string(o)*"):"* string(j)*"\n")
              write(stdout, string(H(A,rule73))*"\033[F\033[F") #Current entropy.

              save(s*lpad(string(j),10,string(0))*".png", colorview(Gray, A))
              end
              write(stdout,"\n")
end
#Takes a dictionary and does a lottery draw with number of tickets equal to the weight.

function HBathDist(o,m,n,s,T,procs)
              A = []
              for i in 1:9
                A = [A..., [true, false]]
              end
              vals = product(A...)
              #pts = [(0,0),(0,1),(0,-1),(1,0)]
              pts = [(a,b) for a in -1:1, b in -1:1]
              A = rand(Bool, (n,n))
              A = SharedArray(A)
              for j in 1:o
              d = 0
              c = 0
              while d < m
              @distributed for batch in 1:10*procs
              k,l = rand(2:n-1),rand(2:n-1)

              C=[A[i,j] for i in max(1,k-2):min(k+2,n), j in max(1,l-2):min(l+2,n)]
              center = (3 + min(k-3,0), 3 + min(l-3,0))
              D = copy(C)
              c = c+1
              mcselect(C, pts,vals,center, T)
              #We want propose replacements for this four-point configuration.

              #There are 2^4 different configurations we can replace it with,
              #and we should propose our options randomly inversely proportionately to their cost.
              #We have to do this because it has to be possible to propose bad moves!

              #print(i," ", δ(A, A.⊻B),"\n")
              if rand() < T*δ(D,C)
              for p in pts
                  A[(p.+(k,l))...]= C[(center.+p)...]
              end
              d=d+1
              #print(d,"\r")
              end
              end
              end
              write(stdout, "Accept rate:"*string(d/c)*"\n") #Step accept rate
              write(stdout, "Step (out of"*string(o)*"):"* string(j)*"\n")
              write(stdout, string(H(A,r))*"\033[F\033[F") #Current entropy.

              save(s*lpad(string(j),10,string(0))*".png", colorview(Gray, A))
              end
              write(stdout,"\n")
end
#Example usage:
#r = rule73
#HBath(10,10,100,"hbath",)
