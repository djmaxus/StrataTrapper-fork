%% MIP upscaling %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc
clear
load ("./Output/post_A2_2")
tol_sw = 1e-3;
tol_kr = 1e-7;
tol_cutoff = tol_kr*0.9999;
tol_average = 0;

% looping through each upscaled grid block
for iii = 1:N_hom_subs_z %number of upscaled grid blocks in z direction
    for jjj = 1:N_hom_subs_x
        for kkk = 1:N_hom_subs_y
            term = (subvol_struct(iii,jjj,kkk).porMat);
            if max(term(:))==0
               subvol_struct(iii,jjj,kkk).in_domain(1) = 0;
               continue
            end
            subvol_struct(iii,jjj,kkk).in_domain(1) = 1;
            count1 = 0;
            count2 = 0;
            count3 = 0;
            count4 = 0;
            count5 = 0;
            count6 = 0;
            
            %Min and max Pc expected in the subvolume.
            min_pc = Brooks_corey_Pc(1, min(min(min(subvol_struct(iii,jjj,kkk).peMat))), swirr,lambda); %we have saved the Pe values from all the fine grid blocks in this structure
            max_pc = Brooks_corey_Pc(sw_aim(1), max(max(max(subvol_struct(iii,jjj,kkk).peMat))), swirr,lambda);

            %Perform MIP for each Sw value.
            for kk = 1:n_pts %n_pts is the number of saturation points we want to use 
                count_reset = 0;
                pc_mid = Brooks_corey_Pc(sw_aim(kk), mean(subvol_struct(iii,jjj,kkk).peMat, 'all', 'omitnan'), swirr,lambda);
                pc_minus = pc_mid*0.90;
                pc_plus = pc_mid*1.10;
                
                if (pc_mid<0) || isnan((pc_mid)) || isinf(pc_mid)
                    disp("Pc is error!")
                end

                count = 0;
                err = 10;
                %Loop until error in Sw is below a tolerance - this way we can
                %generate Pc(Sw) at controlled Sw values.
                %tol_sw = 1e-4;
                while (err > tol_sw) && (count < 150)
                    count = count + 1;
                    sw_plus = 0;
                    sw_minus = 0;
                    sw_mid = 0;

                    sn_plus = 0;
                    sn_minus = 0;
                    sn_mid = 0;

                    %We calculate Pc(Sw) at three values, closely surrounding the mid Pc value,so we can calculate
                    %derivates and move closer to our intended Sw.
                    pc_minus_tot = 0;
                    pc_plus_tot = 0;
                    pc_mid_tot = 0;

                    %If we are at the limits of Pc, the whole domain will be
                    %invaded, If Pc_small > average(Pe)
                    if (pc_minus > (max(max(max(subvol_struct(iii,jjj,kkk).peMat)))))
                        %disp("pc_minus > peMat");
                        subvol_struct(iii,jjj,kkk).invaded_mat_minus(:,:,:,kk) = ones(Nz_sub, Nx_sub, Ny_sub);
                        subvol_struct(iii,jjj,kkk).invaded_mat_mid(:,:,:,kk) = ones(Nz_sub, Nx_sub, Ny_sub);
                        subvol_struct(iii,jjj,kkk).invaded_mat_plus(:,:,:,kk) = ones(Nz_sub, Nx_sub, Ny_sub);
                    else
                        %Check the invasion of the subvolume at this specific pressure value.
                        subvol_struct(iii,jjj,kkk).invaded_mat_minus(:,:,:,kk) = check_box_connectivity_nele(pc_minus, subvol_struct(iii,jjj,kkk).peMat, Nx_sub, Nz_sub, Ny_sub); %check_box_connectivity(pc, Pe_mat, Nx, Nz)
                        subvol_struct(iii,jjj,kkk).invaded_mat_mid(:,:,:,kk) = check_box_connectivity_nele(pc_mid, subvol_struct(iii,jjj,kkk).peMat, Nx_sub, Nz_sub, Ny_sub); %check_box_connectivity(pc, Pe_mat, Nx, Nz)
                        subvol_struct(iii,jjj,kkk).invaded_mat_plus(:,:,:,kk) = check_box_connectivity_nele(pc_plus, subvol_struct(iii,jjj,kkk).peMat, Nx_sub, Nz_sub, Ny_sub);
                        %disp("done with  block connectivity");
                    end

                    %calculate Sw on each fine scale grid.
                    for i = 1:Nz_sub
                        for j = 1:Nx_sub
                            for k = 1:Ny_sub
                                if (subvol_struct(iii,jjj,kkk).invaded_mat_minus(i,j,k,kk) == 1)
                                    sw = Brooks_corey_Sw(pc_minus, subvol_struct(iii,jjj,kkk).peMat(i,j,k), swirr,lambda);
                                else
                                    sw = 1;
                                end

                                %calculate average Pc and Sw, Sn for given conditions.
                                pc_minus_tot = pc_minus_tot + pc_minus.*(1-sw).*subvol_struct(iii,jjj,kkk).porMat(i,j,k);
                                sw_minus = sw_minus + sw.*subvol_struct(iii,jjj,kkk).porMat(i,j,k);
                                sn_minus = sn_minus + (1-sw).*subvol_struct(iii,jjj,kkk).porMat(i,j,k);

                                if (subvol_struct(iii,jjj,kkk).invaded_mat_plus(i,j,k,kk) == 1)
                                    sw = Brooks_corey_Sw(pc_plus, subvol_struct(iii,jjj,kkk).peMat(i,j,k), swirr,lambda);
                                else
                                    sw = 1;
                                end

                                pc_plus_tot =   pc_plus_tot  + pc_plus.*(1-sw).*subvol_struct(iii,jjj,kkk).porMat(i,j,k);
                                sw_plus = sw_plus + sw*subvol_struct(iii,jjj,kkk).porMat(i,j,k);
                                sn_plus = sn_plus + (1-sw)*subvol_struct(iii,jjj,kkk).porMat(i,j,k);

                                if (subvol_struct(iii,jjj,kkk).invaded_mat_mid(i,j,k,kk) == 1)
                                    sw = Brooks_corey_Sw(pc_mid, subvol_struct(iii,jjj,kkk).peMat(i,j,k), swirr,lambda);
                                else
                                    sw = 1;
                                end

                                pc_mid_tot =   pc_mid_tot  + pc_mid.*(1-sw).*subvol_struct(iii,jjj,kkk).porMat(i,j,k);
                                sw_mid = sw_mid + sw.*subvol_struct(iii,jjj,kkk).porMat(i,j,k);
                                sn_mid = sn_mid + (1-sw).*subvol_struct(iii,jjj,kkk).porMat(i,j,k);

                                if (kk == 1) && (count == 1)
                                    subvol_struct(iii,jjj,kkk).por_upscaled = subvol_struct(iii,jjj,kkk).por_upscaled + subvol_struct(iii,jjj,kkk).porMat(i,j,k);
                                end
                            end
                        end
                    end

                    %Work out final average Sw, Pc values at the three locations.

                    sw_mid = sw_mid/subvol_struct(iii,jjj,kkk).por_upscaled;
                    sw_plus = sw_plus/subvol_struct(iii,jjj,kkk).por_upscaled;
                    sw_minus = sw_minus/subvol_struct(iii,jjj,kkk).por_upscaled;

                    pc_minus_tot = pc_minus_tot/(sn_minus);
                    pc_plus_tot = pc_plus_tot/(sn_plus);
                    pc_mid_tot = pc_mid_tot/(sn_mid);

                    if (sn_mid == 0)
                        pc_mid_tot = 0;
                    end
                    if (sn_plus == 0)
                        pc_plus_tot = 0;
                    end

                    if (sn_minus == 0)
                        pc_minus_tot = 0;
                    end

                    %calculate error from intended, vs calculated average Sw
                    if (sn_mid == 0)
                        err = 0;
                    else
                        err = abs(sw_mid - sw_aim(kk))./sw_aim(kk);
                    end

                    %Work out the derivative dSw/dPc.
                    deriv = (sw_plus - sw_minus)/(pc_plus_tot - pc_minus_tot);

                    %Populate datastructures.
                    subvol_struct(iii,jjj,kkk).pc_upscaled(kk) = pc_mid_tot;
                    subvol_struct(iii,jjj,kkk).pb_boundary(kk) = pc_mid;
                    subvol_struct(iii,jjj,kkk).sw_upscaled(kk) = sw_mid;

                    %Find new Pc value to test based on how close we are to the
                    %intended Sw. We will re-iterate if the above error is over
                    %the tolerance.
                    sw_use = sw_aim(kk);
                    pc_mid = pc_mid_tot - (sw_mid-sw_use)./(deriv);
                    pc_mid = abs(pc_mid);

                    %----------- may not be useful for real site---------
%                     if (pc_mid > pc_mid_tot) && (sw_mid<sw_use)
%                         pc_mid = pc_minus;
%                     end
%                     if (pc_mid < min_pc) && (kk<41) %if we arent at end, but method sets it equal to minimum pe, something not right
%                         pc_mid = min_pc + 0.5;
%                         disp("pc_mid is too small")
%                     end
%                     if (isnan(deriv)) && (kk<n_pts-1) %deriv will be nan if sw = 1, pc = 0
%                         disp("nan and k is small ")
%                         pc_mid = min_pc + 0.5;
%                     end
%                     if (count == 149) && (err > 1e-3) %if pc is stuck somewhere, guide the guess based on previous pb_boundary which worked
%                         count = 1;
%                         count_reset = count_reset + 1;
%                         if count_reset > 50
%                             disp(err)
%                             disp("not working")
%                             err = 1e-3;
%                         end
%                         disp("resetting count")
%                         pc_mid = subvol_struct(iii,jjj,kkk).pb_boundary(kk-1);
%                     end
                    %---------------------------------------------------

                    pc_minus = pc_mid*0.90;
                    pc_plus = pc_mid*1.10;
                end

                %With the Sw, Pc distribution for the given pressure invasion,
                %now calculate local Kr for upscaling.
                
                %if (kk == 30)
                %    MM = subvol_struct(iii,jjj,kkk).invaded_mat_mid(:,:,:,30);
                %    MMM = subvol_struct(iii,jjj,kkk).peMat(:,:,:);
                %end
              
                if (kk == n_pts)
                    subvol_struct(iii,jjj,kkk).pc_upscaled(kk) = 0; %ask Nele
                    subvol_struct(iii,jjj,kkk).pb_boundary(kk) = 0;
                    subvol_struct(iii,jjj,kkk).sw_upscaled(kk) = 1;
                end
                
                %Work out fine scale Kr based on Sw 
                for i = 1:Nz_sub
                    for j = 1:Nx_sub
                        for k = 1:Ny_sub
                            if ( subvol_struct(iii,jjj,kkk).invaded_mat_mid(i,j,k,kk) == 1)
                                sw = Brooks_corey_Sw(subvol_struct(iii,jjj,kkk).pb_boundary(kk), subvol_struct(iii,jjj,kkk).peMat(i,j,k), swirr,lambda);
                            else
                                sw = 1;
                            end                
                            %[subvol_struct(iii,jjj,kkk).kg_mat(i,j,k,kk), subvol_struct(iii,jjj,kkk).kw_mat(i,j,k,kk)] = Chierici_rel_perm(sw, swirr,kwsirr, kgsgi, A_water, L_water, B_gas, M_gas);
                            [subvol_struct(iii,jjj,kkk).kg_mat(i,j,k,kk), subvol_struct(iii,jjj,kkk).kw_mat(i,j,k,kk)] = LET_function(sw, swirr, kwsirr, kgsgi, L_w, E_w, T_w, L_g, E_g, T_g);
                            subvol_struct(iii,jjj,kkk).kg_mat(i,j,k,kk) = subvol_struct(iii,jjj,kkk).kg_mat(i,j,k,kk)*subvol_struct(iii,jjj,kkk).permMat(i,j,k);
                            subvol_struct(iii,jjj,kkk).kw_mat(i,j,k,kk) = subvol_struct(iii,jjj,kkk).kw_mat(i,j,k,kk)*subvol_struct(iii,jjj,kkk).permMat(i,j,k);
                        end
                    end
                end

               [subvol_struct(iii,jjj,kkk).kg_phase_connected(kk,1), ~] = check_axis_connectivity_new_nele(subvol_struct(iii,jjj,kkk).kg_mat(:,:,:,kk), Nx_sub, Nz_sub,Ny_sub,tol_kr, 1, Ny_sub);
               % disp("done with direction 1")
               [subvol_struct(iii,jjj,kkk).kg_phase_connected(kk,2), ~] = check_axis_connectivity_new_nele(subvol_struct(iii,jjj,kkk).kg_mat(:,:,:,kk), Nx_sub, Nz_sub,Ny_sub,tol_kr, 2, Nx_sub);
               % disp("done with direction 2")                
               [subvol_struct(iii,jjj,kkk).kg_phase_connected(kk,3), ~] = check_axis_connectivity_new_nele(subvol_struct(iii,jjj,kkk).kg_mat(:,:,:,kk), Nx_sub, Nz_sub,Ny_sub,tol_kr, 3, Nz_sub);
               % disp("done with direction 3")
                
               % disp("moving on to kw")
               [subvol_struct(iii,jjj,kkk).kw_phase_connected(kk,1), ~] = check_axis_connectivity_new_nele(subvol_struct(iii,jjj,kkk).kw_mat(:,:,:,kk), Nx_sub, Nz_sub,Ny_sub,tol_kr, 1, Ny_sub);
               %disp("done with direction 1")
               [subvol_struct(iii,jjj,kkk).kw_phase_connected(kk,2), ~] = check_axis_connectivity_new_nele(subvol_struct(iii,jjj,kkk).kw_mat(:,:,:,kk), Nx_sub, Nz_sub,Ny_sub,tol_kr, 2, Nx_sub);
               % disp("done with direction 2") 
               [subvol_struct(iii,jjj,kkk).kw_phase_connected(kk,3), ~] = check_axis_connectivity_new_nele(subvol_struct(iii,jjj,kkk).kw_mat(:,:,:,kk), Nx_sub, Nz_sub,Ny_sub,tol_kr, 3, Nz_sub);
               % disp("done with direction 3")

               zero_vals = zeros(n_pts,4);

               %If fine scale kr is very low, set it to a tolerance cutoff, so
               %that simulations can still run . Too low phase kr will cause
               %instabilties and is unphysical.

                for i = 1:Nz_sub
                    for j = 1:Nx_sub
                        for k = 1:Ny_sub
                            if ( subvol_struct(iii,jjj,kkk).kg_mat(i,j,k,kk) <= tol_cutoff)
                                subvol_struct(iii,jjj,kkk).kg_mat(i,j,k,kk) =  tol_cutoff;
                            end
                            if ( subvol_struct(iii,jjj,kkk).kw_mat(i,j,k,kk) <=   tol_cutoff)
                                subvol_struct(iii,jjj,kkk).kw_mat(i,j,k,kk) =   tol_cutoff;
                            end
                        end
                    end
                end

                %Count non-zero entries.
                %Direction 1
                if (subvol_struct(iii,jjj,kkk).kg_phase_connected(kk,1) > 0)
                    count1 = count1 +1;
                end
                if (subvol_struct(iii,jjj,kkk).kw_phase_connected(kk,1) < 1)
                    count2 = count2 +1;
                end
                
                %Direction 2 
                if (subvol_struct(iii,jjj,kkk).kg_phase_connected(kk,2) > 0)
                    count3 = count3 +1;
                end
                if (subvol_struct(iii,jjj,kkk).kw_phase_connected(kk,2) < 1)
                    count4 = count4 +1;
                end
                
                %Direction 3
                if (subvol_struct(iii,jjj,kkk).kg_phase_connected(kk,3) > 0)
                    count5 = count5 +1;
                end
                if (subvol_struct(iii,jjj,kkk).kw_phase_connected(kk,3) < 1)
                    count6 = count6 +1;
                end
            end

            %For very points very near the end points (i.e,. low kr), set them
            %to have kr of essentially zero, so that we do not calculate them.
            %They are essentially disconnected, having maybe only one very low
            %kr pathway connecting, which will cause numerical issues. The w
            %loop can be varied to exclude more values from the scheme, but
            %these were found to work well. Excluding these values is simply
            %numerical, since when working out the upscaled kr for subseqnet
            %simulations, it is a fit to the included, calculated values, so we
            %still recover these low values - they are just not numerically
            %stable.
            
            %Direction 1
            for w = 1:5
                if ((count1 - (w-1))>0)
                    subvol_struct(iii,jjj,kkk).kg_phase_connected(count1 - (w-1),1) = 0;
                end
            end            
            for w = 1:5
                subvol_struct(iii,jjj,kkk).kw_phase_connected(count2+w,1) = 0;
            end
            
            %Direction 2
            for w = 1:5
                if ((count3 - (w-1))>0)
                    subvol_struct(iii,jjj,kkk).kg_phase_connected(count3 - (w-1),2) = 0;
                end
            end
            for w = 1:5
                subvol_struct(iii,jjj,kkk).kw_phase_connected(count4+w,2) = 0;
            end            
            
            %Direction 3    
            for w = 1:5
                if ((count5 - (w-1))>0)
                    subvol_struct(iii,jjj,kkk).kg_phase_connected(count5 - (w-1),3) = 0;
                end
            end           
            for w = 1:5
                subvol_struct(iii,jjj,kkk).kw_phase_connected(count6+w,3) = 0;
            end

            %Work out upscaled porosity.
            subvol_struct(iii,jjj,kkk).por_upscaled = subvol_struct(iii,jjj,kkk).por_upscaled/(Nz_sub*Nx_sub*Ny_sub);

            disp(['Successfull MIP for subvol #', int2str(iii), ',', int2str(jjj), ',', int2str(kkk),' out of. Z=', int2str(N_hom_subs_z), 'x=', int2str(N_hom_subs_x), 'y=', int2str(N_hom_subs_y)])
            disp('')            
        end
    end
end



% I added in some code here to do some error correction in the rel perms to avoid numerical issues
% essentially ensures that the rel perms are smooth before trying to upscale 
count = 0;
count2 = 0;
hold on
for i = 1:N_hom_subs_z
    for j = 1:N_hom_subs_x
        for k = 1:N_hom_subs_y
             if (subvol_struct(i,j,k).in_domain(1) == 1)                
                count = count + 1;
                for kk = 39:42
                    if (subvol_struct(i,j,k).sw_upscaled(kk) < 0.7) 
                        count2 = count2 +1;    
                        lll(count2,1) = i;
                        lll(count2, 2) = j;
                        lll(count2,3) = k;
                        lll(count2,4) = kk;

                        %remove numerical errors   
                        subvol_struct(i,j,k).sw_upscaled(kk) = subvol_struct(i,j,k).sw_upscaled(kk-1) + 0.02;
                        subvol_struct(i,j,k).pc_upscaled(kk) = subvol_struct(i,j,k).pc_upscaled(kk-1)*0.9;
                        subvol_struct(i,j,k).kg_phase_connected(kk,:) = 0;
                        subvol_struct(i,j,k).kw_phase_connected(kk,:) = 1;

                        for ii = 1:Nz_sub
                            for jj = 1:Nx_sub
                                for kkk = 1:Ny_sub
                                    [subvol_struct(i,j,k).kg_mat(ii,jj,kkk,kk), subvol_struct(i,j,k).kw_mat(ii,jj,kkk,kk)] = LET_function(1, swirr, kwsirr, kgsgi, L_w, E_w, T_w, L_g, E_g, T_g);         
                                    subvol_struct(i,j,k).kg_mat(ii,jj,kkk,kk) = subvol_struct(i,j,k).kg_mat(ii,jj,kkk,kk)*subvol_struct(i,j,k).permMat(ii,jj,kkk);
                                    subvol_struct(i,j,k).kw_mat(ii,jj,kkk,kk) = subvol_struct(i,j,k).kw_mat(ii,jj,kkk,kk)*subvol_struct(i,j,k).permMat(ii,jj,kkk);
                                    if ( subvol_struct(i,j,k).kg_mat(ii,jj,kkk,kk) <= tol_cutoff)
                                        subvol_struct(i,j,k).kg_mat(ii,jj,kkk,kk) =  tol_cutoff;
                                   end
    
                                    if ( subvol_struct(i,j,k).kw_mat(ii,jj,kkk,kk) <= tol_cutoff)
                                        subvol_struct(i,j,k).kw_mat(ii,jj,kkk,kk) =   tol_cutoff;
                                    end
                                end
                            end
                        end
                    end           
                end
             end
        end
    end
end

count_kg_1_error = 0;
count_kg_2_error = 0;
count_kg_3_error = 0;
count_kw_1_error = 0;
count_kw_2_error = 0;
count_kw_3_error = 0;
count_g_total = 0;
count_w_total = 0;

% 
for iii = 1:N_hom_subs_z
    for jjj = 1:N_hom_subs_x
        for kkk = 1: N_hom_subs_y
            if (subvol_struct(iii,jjj,kkk).in_domain(1) == 1)
                for cc = 1:(n_pts-1)
                    if (subvol_struct(iii,jjj,kkk).kg_phase_connected(cc,1) == 0) && (subvol_struct(iii,jjj,kkk).kg_phase_connected(cc+1,1) == 1)
                        count_kg_1_error = count_kg_1_error + 1;
                        count_g_total = count_g_total+1;
                        ccc(count_g_total,1) = iii;
                        ccc(count_g_total,2) = jjj;
                        ccc(count_g_total,3) = kkk;
                        ccc(count_g_total,4) = cc;
                        subvol_struct(iii,jjj,kkk).kg_phase_connected(cc+1,1) = 0;
                    end
                    if (subvol_struct(iii,jjj,kkk).kg_phase_connected(cc,2) == 0) && (subvol_struct(iii,jjj,kkk).kg_phase_connected(cc+1,2) == 1)
                        count_kg_2_error = count_kg_2_error + 1;
                        count_g_total = count_g_total+1;
                        ccc(count_g_total,1) = iii;
                        ccc(count_g_total,2) = jjj;
                        ccc(count_g_total,3) = kkk;
                        ccc(count_g_total,4) = cc;
                        subvol_struct(iii,jjj,kkk).kg_phase_connected(cc+1,2) = 0;
                    end                    
                    if (subvol_struct(iii,jjj,kkk).kg_phase_connected(cc,3) == 0) && (subvol_struct(iii,jjj,kkk).kg_phase_connected(cc+1,3) == 1)
                        count_kg_3_error = count_kg_3_error + 1;
                        count_g_total = count_g_total+1;
                        ccc(count_g_total,1) = iii;
                        ccc(count_g_total,2) = jjj;
                        ccc(count_g_total,3) = kkk;
                        ccc(count_g_total,4) = cc;
                        subvol_struct(iii,jjj,kkk).kg_phase_connected(cc+1,3) = 0;
                    end
                end
                
                %WATER
                for cc = 1:(n_pts-1)    
                    if (subvol_struct(iii,jjj,kkk).kw_phase_connected(cc,1) == 1) && (subvol_struct(iii,jjj,kkk).kw_phase_connected(cc+1,1) == 0)
                        count_kw_1_error = count_kw_1_error + 1;
                        count_w_total = count_w_total+1;
                        cccc(count_w_total,1) = iii;
                        cccc(count_w_total,2) = jjj;
                        cccc(count_w_total,3) = kkk;
                        cccc(count_w_total,4) = cc;
                        subvol_struct(iii,jjj,kkk).kw_phase_connected(cc,1) = 0;
                    end
                    
                    if (subvol_struct(iii,jjj,kkk).kw_phase_connected(cc,2) == 1) && (subvol_struct(iii,jjj,kkk).kw_phase_connected(cc+1,2) == 0)
                        count_kw_2_error = count_kw_2_error + 1;
                        count_w_total = count_w_total+1;
                        cccc(count_w_total,1) = iii;
                        cccc(count_w_total,2) = jjj;
                        cccc(count_w_total,3) = kkk;
                        cccc(count_w_total,4) = cc;
                        subvol_struct(iii,jjj,kkk).kw_phase_connected(cc,2) = 0;                    
                    end
                    
                    if (subvol_struct(iii,jjj,kkk).kw_phase_connected(cc,3) == 1) && (subvol_struct(iii,jjj,kkk).kw_phase_connected(cc+1,3) == 0)
                        count_kw_3_error = count_kw_3_error + 1;
                        count_w_total = count_w_total+1;
                        cccc(count_w_total,1) = iii;
                        cccc(count_w_total,2) = jjj;
                        cccc(count_w_total,3) = kkk;
                        cccc(count_w_total,4) = cc;
                        subvol_struct(iii,jjj,kkk).kw_phase_connected(cc,3) = 0;                    
                    end
                end   
            end
        end
    end
end

save("./Output/post_A3_1", '-v7.3')

for iii = 1:N_hom_subs_z %number of upscaled grid blocks in z direction
    for jjj = 1:N_hom_subs_x
        for kkk = 1:N_hom_subs_y
            A(iii,jjj,kkk) = subvol_struct(iii,jjj,kkk).por_upscaled;
        end
    end
end
filename1 = './Output/Porosity_upscaled.vtk';
A(isnan(A)) = 0;
[X,Y,Z] = meshgrid(1:size(A,2),1:size(A,1),1:size(A,3));
vtkwrite(filename1,'structured_grid',X,Y,Z,'scalars','Por',A)

for iii = 1:N_hom_subs_z %number of upscaled grid blocks in z direction
    for jjj = 1:N_hom_subs_x
        for kkk = 1:N_hom_subs_y
            A(iii,jjj,kkk) = subvol_struct(iii,jjj,kkk).pc_upscaled(end);
        end
    end
end
filename1 = './Output/Pe_upscaled.vtk';
A(isnan(A)) = 0;
[X,Y,Z] = meshgrid(1:size(A,2),1:size(A,1),1:size(A,3));
vtkwrite(filename1,'structured_grid',X,Y,Z,'scalars','Pe',A)