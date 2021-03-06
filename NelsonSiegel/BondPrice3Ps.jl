function BondPrice3Ps(y,c0,t,FaceValue=1)
#BondPrice3Ps   Calculates price from the yield to maturity and the payment
#               stream (arbitrary periods and coupons)
#
#
#
#
#
#  Usage:     [Q,dQ_dy] = BondPrice3Ps(y,c0,t[,FaceValue]);
#
#  Input:
#             y          n vector, effective yield to maturity, e.g. 0.07
#             c0         scalar or n vector or nxm matrix , coupon rate and face value,
#                        e.g. 0.06 or 0.09/2
#             t          m vector, dates of coupon payments. Principal
#                        is paid at the same time as the last coupon. Dates
#                        should be expressed as fractions of the period.
#             FaceValue  (optional) face value (default: 1)
#
#  Output:    Q      n vector, bond price (eg. 1.01)
#             dQ_dy  n vector, derivative of bond price wrt. yield
#
#
#
#  Note: (1) the following is calculated:
#
#             Q =  c/(1+y)^t(1) + c/(1+y)^t(2) + ... + (1+c)/(1+y)^t(m)
#
#        (2) With semi-annual coupons after 2,8, and 14 months, use
#            t = [0.333;0.333+1;0.333+2] to calculate semiannual yield.
#
#
#
#  Example:        t = (1:2)'
#                  c = [0.09 0.09;
#                       0.10 0.10];
#                  y = [0.0626;0.07];  gives Q = [1.05;1.05]
#
#
#
#   Paul Soderlind (Paul.Soderlind@unisg.ch), June 2009, to Julia 2015
# ----------------------------------------------------------------------------

  y = vecPs(y)
  t = vecPs(t)

  n = length(y)
  m = length(t)
  y = repmat(y,1,m)                         #n -> nxm
  t = repmat(t',n,1)                        #m -> nxm matrix

  c = deepcopy(c0)                          #breaks link with c0 argument
  if length(c) == 1                         #scalar c
    c = fill(c,(n,m))
  elseif length(c) == n                     #one c for each bond
    c = repmat(c,1,m)
  end
  if length(FaceValue) == 1
    FaceValue = fill(FaceValue,(n,1))
  end
  c[:,end] = c[:,end] + FaceValue           #add face value to last coupon payment

  cfac  = c./((1+y).^t)                     #c/(1+y)^t1 + c/(1+y)^t2 + ...+ c/(1+y)^m
  Q     = sum(cfac,2)                       #theoretical price

  dcfac = cfac .* (-t./(1+y))               #derivative wrt ytm
  dQ_dy = sum(dcfac,2)

  return Q,dQ_dy

end
#-----------------------------------------------------------------------------


#-----------------------------------------------------------------------------

function BondYieldToMat3Ps(Q,c,t,Method=1,yLH=[-0.1;0.5],tol=1e-7,FaceValue=1)
#BondYieldToMat3Ps    Calculates yield to maturity from bond price (several methods available).
#                     Can also be used for general IRR calculations. Works with arbitrary
#                     coupon periods.
#
#
#  Usage:     y = BondYieldToMat3Ps(Q,c,t[,Method[,yLH[,tol[,FaceValue]]]])
#
#
#  Input:     Q          nx1 vector, bond prices (for instance, 1.01)
#             c          scalar or n vector or nxm matrix, c rate, e.g. 0.06, or 0.09/2
#             t          mx1 vector, dates of coupon payments. Principal
#                        is paid at the same time as the last c. Dates
#                        should be expressed as fractions of the period.
#                        Example: coupons after 2,8, and 14 months with semi-annual coupons->
#                        t = [0.333;0.333+1;0.333+2]
#             Method     optional, 1: Newton-Raphson; 2: bisection [1]
#             yLH        optional, if Method==1: scalar, yLH[1] is initial guess of roots
#                                  if Method==2: 2x1 vector, yLH[1] is lower boundary and yLH[2] upper boundary
#             tol        optional, scalar, convergence criterion for y, [1e-7]
#             FaceValue  optional, scalar, face value, default [1]
#
#  Output:    y        nx1 vector, effective yield to maturity (per period)
#
#
#
#  Note:      (1)  Method 1 (Newton-Raphson) is pretty fast. The Newton-Raphson iterations
#                  are based on
#                  Q = F(y0) + J0*Dy, where Dx = y1-y0 and J0 is the Jacobian at y0.
#                  We choose Dy to make this exact, that is as  (Q - F(y0))./J0 = Dy
#
#             (2)  Method 2 (bisection) is a bit slow, but very robust.
#
#             (3) The formula is
#             Q =  c/y1^t(1) + c/y1^t(2) + ... + (1+c)/y1^t(m)#
#             with y1 = 1+y, where y is the yield to maturity,
#             c is per period coupon and y1 the gross yield (per period)
#             to maturity
#
#             (4) To use for IRR calculations, set Q=0 and FaceValue=0
#
#             (5) for Newton-Raphson, we could use (c+(FaceValue-B)/n)/((FaceValue+B)/2)
#                 as a good starting value
#
#
#  Calls on:  BondPrice3Ps
#
#
#  Paul Soderlind (Paul.Soderlind@unisg.ch), June 2009, to Julia 2015
#------------------------------------------------------------------------------

  n = length(Q)
  #--------------------------------------

  if Method == 1                   #Newton-Raphson

    y = fill(yLH[1],n)
    Dy = 1e+198
    while maximum(abs(Dy)) > tol
      (F0,J0) = BondPrice3Ps(y,c,t,FaceValue)  #F(y0) and derivative, nx1
      Dy = (Q - F0)./J0                         #nx1
      y  = y + Dy
    end
  #--------------------------------------

  elseif Method == 2                   #bisection

    yL = repmat([yLH[1]],n,1)           #lower boundary for yield
    yH = repmat([yLH[2]],n,1)           #upper boundary
    if any(yL .> yH)
      warn("Lower bound greater than upper bound")
    end
    Q0, = BondPrice3Ps(yL,c,t,FaceValue)     #create starting value, so [yL,yH] brackets the roots
    while any(Q0 .< Q)                       #as long as theoretical < actual price
      vv = Q0 .< Q
      yL[vv] = yL[vv] - 0.01
      println(yL)
      Q0, = BondPrice3Ps(yL,c,t,FaceValue)
    end
    Q0, = BondPrice3Ps(yH,c,t,FaceValue)
    while any(Q0 .> Q)
      vv = Q0 .> Q
      yH[vv] = yH[vv] + 0.01
      Q0, = BondPrice3Ps(yH,c,t,FaceValue)
    end

    y = (yL + yH)/2
    while any((yH-yL) .> tol)              #iteration loop
      y = (yL + yH)/2                      #mid point for yield
      Qs, = BondPrice3Ps(y,c,t,FaceValue)  #price at guessed yield
      vvH     = Qs .>= Q                   #logical where Qs >= Q  (decreasing function)
      yL[vvH] = y[vvH]                     # => root must be higher than y
      vvL     = Qs .< Q                    #logical where Qs < Q
      yH[vvL] = y[vvL]                     # -> root must be lower than y
    end
  #--------------------------------------

  end                                      #end different methods
  return y

end
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
function BondDurationMacaulay3Ps(Q,c0,t,Method=1,yLH=[-0.1;0.5],tol=1e-7,FaceValue=1)
#DurationMacaulay2Ps   Calculates Macaulay's duration. See also BondYieldToMat3Ps
#
#
#
#
#
#  Usage:     (D,Da,Dmac,ytm) = BondDurationMacaulay3Ps(Q,c,t[,Method[,yLH[,tol[,FaceValue]]]])
#
#  Input:     Q         nx1 vector, bond prices (for instance, 1.01)
#             c0    scalar or n vector or nxm matrix, c rate, e.g. 0.06, or 0.09/2
#             t         mx1 vector, dates of coupon payments. Principal
#                       is paid at the same time as the last c. Dates
#                       should be expressed as fractions of the period
#                          Example: coupons after 2,8, and 14 months ->
#                       t = [0.333;0.333+1;0.333+2], to calculate semi-annual yield
#             Method    (optional) 1: Newton-Raphson; 2: bisection [1]
#             yLH       (optional) if Method==1: scalar, yLH(1) is initial guess of roots
#                                  if Method==2: 2x1 vector, yLH(1) is lower boundary and yLH(2) upper boundary
#             tol       (optional) scalar, convergence criterion for y, [1e-7]
#             FaceValue (optional), scalar, face value (default [1])
#
#  Output:    D        nx1 vector, (dollar) duration
#             Da        ""       , adjusted (or modified) duration
#             Dmac      ""       , Macaulays duration
#             ytm
#
#
#  Note:  (a)     The bond price satisfies (with yield expressed per period)
#
#                 Q =  c/(1+y)^t(1) + c/(1+y)^t(2) + ... + (1+c)/(1+y)^t(m)
#
#                 where y is the yield to maturity, c is per period coupon
#                 and Macaulay's duration is
#
#          D =  [t(1)*c/(1+y)^t(1) + t(2)*c/(1+y)^t(2) + ... + t(m)*(1+c)/(1+y)^t(m)]/Q
#
#
#
#
#  Reference: Campbell. Lo, MacKinlay, p 403.
#
#
#  Calls on:  BondYieldToMat3Ps
#
#  Paul Soderlind (Paul.Soderlind@unisg.ch), June 2009
#------------------------------------------------------------------------------

  Q = vecPs(Q)                        # -> column vector
  t = vecPs(t)

  n  = length(Q)
  m  = length(t)

  ytm = BondYieldToMat3Ps(Q,c,t,Method,yLH,tol,FaceValue)  #yield to maturity, effective interest rate
  y = repmat(ytm,1,m)          #n -> nxm, maturity x bond
  t = repmat(t',n,1)           #m -> nxm

  c = deepcopy(c0)         #breaks link with c argument
  if length(c) == 1
    c = fill(c,(n,m))
  elseif length(c) == n
    c = repmat(c,1,m)
  end
  if length(FaceValue) == 1
    FaceValue = fill(FaceValue,(n,1))     # -> nx1
  end
  c[:,end] = c[:,end] + FaceValue      #add face value to last coupon payment
  cfac  = c.*t./((1+y).^(t+1))         #c/(1+y)^2 + 2c/(1+y)^3 + ...+ Tc/(1+y)^(T+1)

  D    = sum(cfac,2)                   #Duration, row vector
  Da   = D ./ Q                        #adjusted duration
  Dmac = D .* (1+y[:,m])./ Q           #Macaulays duration

  return D,Da,Dmac,ytm

end
#------------------------------------------------------------------------------
