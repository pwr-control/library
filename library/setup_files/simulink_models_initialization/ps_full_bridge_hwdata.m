function ps_full_bridge = ps_full_bridge_hwdata(CFi, RCFi, LFu, RLFu, CFu1, RCFu1, CFu2, RCFu2, udc_nom, udc_bez, u_nom, i_nom, u_bez, i_bez, fpwm)

    ps_full_bridge = hw_ps_full_bridge_setup(CFi, RCFi, LFu, RLFu, CFu1, RCFu1, CFu2, RCFu2, udc_nom, udc_bez, u_nom, i_nom, u_bez, i_bez, fpwm);

end
