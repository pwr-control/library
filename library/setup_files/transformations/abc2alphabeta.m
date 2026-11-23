function [alpha,beta] = abc2alphabeta(a,b,c)

alpha = 2/3*(a - 1/2*b - 1/2*c);
beta  = 1/sqrt(3)*(b - c);

end